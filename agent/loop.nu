# The agent loop: call the model, run the tools it asks for, repeat until it
# answers. One entry point, `run-agent`, and it always returns a record:
#
#   {
#     status: "done" | "truncated" | "max_turns" | "budget_exceeded" | "error"
#     answer: string | null     # the model's final text, if it produced any
#     error: string             # what went wrong, when status is "error"
#     messages: list            # the whole conversation, system prompt included
#     usage: { prompt_tokens, completion_tokens, total_tokens, calls, cost_usd }
#                               # the whole run's, sub-agents included
#     iterations: int           # model calls made by this agent
#     run_id: string, journal: string | null   # this run's id, and the event journal
#                               # it was written to (see agent/events.nu), if any
#     session: string | null    # the session it was saved to (agent/session.nu), if any
#     subagents: list           # one { name, status, iterations, usage,
#                               #   subagents } per sub-agent call it made
#   }
#
#   done       the model finished its answer
#   truncated  the model hit its output limit mid-answer (`answer` is the part
#              it wrote) -- raise max_tokens
#   max_turns  the model was still calling tools when it ran out of iterations;
#              the last turn asks it to answer from what it has gathered, so
#              `answer` is usually still set
#   budget_exceeded  the run used up its max_total_tokens / max_cost_usd
#              (agent/context.nu); `answer` is whatever text the model had
#              produced with its last tool calls, if any
#   error      a model call failed after its retries (`error` says why);
#              `messages` holds everything up to that point
#
# With `--session <id>` the conversation is saved as it goes and a later run with
# the same id continues it, even after a crash (agent/session.nu). An empty query
# means "carry on from where the session stopped".
#
# An agent whose config lists `agents` can call them as tools: each call builds
# that agent from the same manifest and runs it, on a fresh conversation, with
# `run-agent` -- so the same rules apply at every level. A sub-agent's answer is
# the tool result; its failure is an "Error: ..." result the calling model can
# react to. Recursion is bounded two ways: cycles are rejected when the agent is
# loaded (agent/registry.nu), and nesting deeper than $env.AGENT_MAX_DEPTH
# (default 4) is refused at call time.
#
# Everything that happens is reported as events (agent/events.nu): to a journal
# file, the console, an OTel collector -- whichever sinks are selected.
#
# run-agent does not raise for model or tool failures -- a tool failure is fed
# back to the model as text, a model failure is a status -- so a caller can
# always inspect what happened.
use events.nu [run-context, emit, flush, new-id, now-ns, child-parent]
use session.nu [load-session, save-session, session-dir]
use context.nu [effective-limits, over-budget, remaining-limits, estimate-tokens, compact-messages]
use ../tools/runtime.nu *
use registry.nu [get-agent]

# Asked on the last permitted iteration: hitting the cap would otherwise
# discard everything the agent learned and return nothing.
const FINAL_TURN_PROMPT = "You have used your tool budget. Do not call any more tools. Give your final answer now, in the format your instructions require, using only what you have already gathered, and say plainly what you did not get to."

def zero-usage [] {
    { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0, calls: 0, cost_usd: null }
}

def add-usage [total: record, step: record] {
    let spent = ($step.cost | get -o cost_usd | default null)
    {
        prompt_tokens: ($total.prompt_tokens + ($step.usage | get -o prompt_tokens | default 0))
        completion_tokens: ($total.completion_tokens + ($step.usage | get -o completion_tokens | default 0))
        total_tokens: ($total.total_tokens + ($step.usage | get -o total_tokens | default 0))
        calls: ($total.calls + 1)
        cost_usd: (if $spent == null { $total.cost_usd } else { ($total.cost_usd | default 0.0) + $spent })
    }
}

# Fold one usage record into another (a finished sub-agent's into its caller's,
# or a run's into its session's running total).
def merge-usage [total: record, child: record] {
    let spent = ($child | get -o cost_usd | default null)
    {
        prompt_tokens: ($total.prompt_tokens + ($child.prompt_tokens? | default 0))
        completion_tokens: ($total.completion_tokens + ($child.completion_tokens? | default 0))
        total_tokens: ($total.total_tokens + ($child.total_tokens? | default 0))
        calls: ($total.calls + ($child.calls? | default 0))
        cost_usd: (if $spent == null { $total.cost_usd } else { ($total.cost_usd | default 0.0) + $spent })
    }
}

def ms-since [start_ns: int] {
    (((now-ns) - $start_ns) / 1_000_000) | into int
}

def warn [message: string] {
    print --stderr $"warning: ($message)"
}

# One model call. Returns { message, finish_reason, usage, cost, retries, raw };
# raises if the call fails.
def model-step [agent: record] {
    let result = (do $agent.model_call $agent.messages)
    let choice = ($result | get -o choices.0)
    if $choice == null {
        error make { msg: "the provider returned no choices" }
    }
    {
        message: $choice.message
        finish_reason: ($choice.finish_reason? | default "stop")
        usage: ($result | get -o usage | default {})
        cost: ($result | get -o cost | default {})
        retries: ($result | get -o retry_attempts | default 1)
        raw: ($result | to json --raw)
    }
}

def failed [error: string] {
    { ok: false, content: "", error: $error }
}

# Save a snapshot of the conversation to the run's session (if it has one).
# Returns { sess, error }: `sess` is the session record to carry forward (null
# once persistence has failed -- it warns and the run carries on), `error` is
# set only for a conflict with another process, which must stop the run.
def snapshot [sess: any, messages: list, status: string, base_total: record, usage: record] {
    if $sess == null {
        return { sess: null, error: "" }
    }
    let saved = (save-session ($sess | merge { messages: $messages, status: $status, usage_total: (merge-usage $base_total $usage) }))
    if $saved.ok {
        { sess: $saved.session, error: "" }
    } else if $saved.conflict {
        { sess: $sess, error: $saved.error }
    } else {
        warn $"cannot save session '($sess.id)': ($saved.error) -- continuing without saving it"
        { sess: null, error: "" }
    }
}

# Run sub-agent `name` on `args.query`, nested under the tool call's span and
# limited to what is left of the caller's budget. Returns { result, child }:
# `result` is the { ok, content, error } the calling model gets, `child` the
# summary that goes in the run's `subagents` (null if it never ran).
def subagent-step [agent: record, name: string, args: record, ctx: record, span: string, depth: int, limits: record, usage: record] {
    let max_depth = ($env.AGENT_MAX_DEPTH? | default 4 | into int)
    if $depth >= $max_depth {
        return { result: (failed $"Sub-agent nesting limit \(($max_depth)\) reached; '($name)' was not run"), child: null }
    }
    if (over-budget $usage $limits) != null {
        return { result: (failed $"This run's budget is used up; sub-agent '($name)' was not run"), child: null }
    }
    let query = ($args | get -o query | default null)
    if ($query | describe) != "string" or ($query | str trim | is-empty) {
        return { result: (failed $"'($name)' needs a non-empty string argument 'query'"), child: null }
    }
    if $agent.manifest == null {
        return { result: (failed $"Cannot run '($name)': this agent was not built through a manifest"), child: null }
    }
    let built = (try { get-agent $name --manifest $agent.manifest } catch {|e| return { result: (failed $e.msg), child: null } })
    let run = ($built | run-agent $query --parent (child-parent $ctx $span) --depth ($depth + 1) --budget (remaining-limits $usage $limits))

    let child = { name: $name, run_id: $run.run_id, status: $run.status, iterations: $run.iterations, usage: $run.usage, subagents: $run.subagents }
    let result = (match $run.status {
        "error" => (failed $"Sub-agent '($name)' failed: ($run.error)")
        "done" => { ok: true, content: ($run.answer | default ""), error: "" }
        _ => {
            let why = (match $run.status {
                "truncated" => "hit its output limit"
                "budget_exceeded" => "ran out of budget"
                _ => "ran out of iterations"
            })
            if ($run.answer | is-empty) {
                failed $"Sub-agent '($name)' ($why) without producing an answer"
            } else {
                { ok: true, content: $"[Note: sub-agent '($name)' ($why); its answer may be incomplete]\n($run.answer)", error: "" }
            }
        }
    })
    { result: $result, child: $child }
}

# Run one tool call -- a tool function, or another agent -- reporting it as
# tool.start / tool.end events. Returns { message, child, ctx }: the "tool"
# message to append to the conversation, the sub-agent summary when the call was
# to one, and the updated run context. Nothing here raises: a failed tool is a
# result the model gets to see.
def tool-step [agent: record, call: record, ctx: record, iter_span: string, depth: int, limits: record, usage: record] {
    let name = $call.function.name
    let call_id = ($call.id? | default "")
    let args_text = ($call.function.arguments | if ($in | describe) == "string" { $in } else { to json --raw })
    let span = (new-id 16)
    let started = (now-ns)
    mut c = (emit $ctx "tool.start" { ts_ns: $started, span_id: $span, parent_span_id: $iter_span, tool: $name, call_id: $call_id, content: { args: $args_text } })

    let outcome = (if $name in $agent.tools.subagents {
        # same checks as a tool: declared, valid arguments, allowed by policy
        let prepared = (prepare-call $agent.tools $call.function)
        if $prepared.ok {
            subagent-step $agent $name $prepared.args $c $span $depth $limits $usage
        } else {
            { result: (failed $prepared.error), child: null }
        }
    } else {
        { result: (run-tool $agent.tools $call.function), child: null }
    })

    let result = $outcome.result
    let text = (tool-result-text $result)
    $c = (emit $c "tool.end" {
        span_id: $span, parent_span_id: $iter_span, start_ns: $started
        tool: $name, call_id: $call_id, ok: $result.ok, duration_ms: (ms-since $started)
        error: $result.error
        child_run_id: (if $outcome.child == null { null } else { $outcome.child.run_id })
        content: { result: $text }
    })
    {
        message: { role: "tool", name: $name, content: $text, tool_call_id: $call_id }
        child: $outcome.child
        ctx: $c
    }
}

# Run the agent on `query` (piped-in agent record, from `agent`). An empty query
# continues a session from where it stopped.
#   --session <id>       save the conversation as it goes, and continue it if the
#                        session already exists (agent/session.nu)
#   --require-existing   with --session: it is an error if there is no such session
#   --sinks              event sinks, overriding $env.AGENT_SINKS (agent/events.nu)
#   --parent             { trace_id, span_id } of an external trace to nest under
#                        (the loop passes more, so sub-agents share a journal)
#   --depth, --budget    set by the loop for sub-agents: how deep, and what is left
#                        of the caller's budget; callers leave them alone
export def run-agent [
    query: string = ""
    --session: any = null
    --require-existing
    --sinks: any = null
    --parent: record = {}
    --depth: int = 0
    --budget: record = {}
] {
    let agent = $in
    let run_span = (new-id 16)
    let run_start = (now-ns)

    # ---- the conversation to start from: a saved session, or a fresh one
    let existing = (if $session == null { null } else { load-session $session })
    if $session != null and $existing == null and $require_existing {
        error make { msg: $"No session '($session)' in (session-dir)" }
    }
    if $existing != null and $existing.agent != $agent.name {
        error make { msg: $"Session '($session)' belongs to agent '($existing.agent)', not '($agent.name)'" }
    }
    let continuing = ($query | is-empty)
    let base_messages = (if $existing != null { $existing.messages } else { $agent.messages })
    if $continuing {
        if $existing == null {
            error make { msg: "Nothing to run: no query was given and there is no session to continue" }
        }
        if ($base_messages | last | get role) == "assistant" {
            error make { msg: $"Session '($session)' is complete \(its last message is the model's answer\): give a follow-up query to continue it" }
        }
    }
    let base_total = ($existing | default {} | get -o usage_total | default (zero-usage))
    mut messages = (if $continuing { $base_messages } else { $base_messages | append { role: "user", content: $query } })
    mut usage = (zero-usage)

    mut sess = (if $session == null { null } else {
        {
            id: $session, agent: $agent.name, runtime: $agent.runtime, model: $agent.model
            status: "running", rev: ($existing | default {} | get -o rev | default 0)
            created: ($existing | default {} | get -o created | default (date now | format date "%Y-%m-%dT%H:%M:%SZ"))
            runs: (($existing | default {} | get -o runs | default 0) + 1)
            messages: $messages, usage_total: $base_total
        }
    })
    let first = (snapshot $sess $messages "running" $base_total $usage)
    if $first.error != "" {
        error make { msg: $first.error }
    }
    $sess = $first.sess

    mut ctx = (run-context $agent $parent $depth $sinks)
    $ctx = (emit $ctx "run.start" {
        ts_ns: $run_start, span_id: $run_span, parent_span_id: $ctx.parent_span_id
        runtime: $agent.runtime, model: $agent.model, max_iterations: $agent.max_iterations
        session: $session
        content: { query: $query }
    })

    let limits = (effective-limits $agent.budget $budget)
    mut status = "max_turns"
    mut answer: any = null
    mut last_content: any = null
    mut error = ""
    mut turns = 0
    mut children = []
    mut last_prompt_tokens = 0
    mut warned_cost = false

    for turn in 1..$agent.max_iterations {
        # Compact before a call that would otherwise carry a bloated history:
        # old tool outputs become markers (agent/context.nu).
        if $agent.context != null {
            let estimate = ([$last_prompt_tokens (estimate-tokens $messages)] | math max)
            if $estimate > $agent.context.max_prompt_tokens {
                let compacted = (compact-messages $messages $agent.context.keep_rounds $agent.context.min_result_chars)
                if $compacted.elided > 0 {
                    $messages = $compacted.messages
                    $ctx = (emit $ctx "context.compacted" { elided: $compacted.elided, chars_saved: $compacted.chars_saved, estimated_tokens: $estimate, max_prompt_tokens: $agent.context.max_prompt_tokens })
                }
            }
        }

        # Stop before spending more once the allowance is used up.
        let over = (over-budget $usage $limits)
        if $over != null {
            $ctx = (emit $ctx "budget.exceeded" { limit: $over.limit, used: $over.used, max: $over.max })
            $status = "budget_exceeded"
            $answer = $last_content
            break
        }

        $turns = $turn
        # On the last permitted iteration, ask for the answer instead of letting
        # the agent spend it on another tool call.
        if $turn == $agent.max_iterations and $turn > 1 {
            $messages = ($messages | append { role: "user", content: $FINAL_TURN_PROMPT })
        }
        let iter_span = (new-id 16)
        let iter_start = (now-ns)
        $ctx = (emit $ctx "iteration.start" { ts_ns: $iter_start, span_id: $iter_span, parent_span_id: $run_span, iteration: $turn })

        let model_span = (new-id 16)
        let model_start = (now-ns)
        $ctx = (emit $ctx "model.start" { ts_ns: $model_start, span_id: $model_span, parent_span_id: $iter_span, runtime: $agent.runtime, model: $agent.model, messages: ($messages | length) })
        let step = (try {
            model-step ($agent | upsert messages $messages)
        } catch {|e|
            { failed: $e.msg }
        })
        let model_fields = { span_id: $model_span, parent_span_id: $iter_span, start_ns: $model_start, runtime: $agent.runtime, model: $agent.model, duration_ms: (ms-since $model_start) }

        if "failed" in $step {
            $ctx = (emit $ctx "model.end" ($model_fields | merge { ok: false, usage: {}, cost: {}, finish_reason: "", retries: 0, error: $step.failed }))
            $ctx = (emit $ctx "iteration.end" { span_id: $iter_span, parent_span_id: $run_span, start_ns: $iter_start, iteration: $turn, finish_reason: "", error: $step.failed })
            $ctx = (flush $ctx)
            $status = "error"
            $error = $step.failed
            break
        }
        $usage = (add-usage $usage $step)
        $last_prompt_tokens = ($step.usage | get -o prompt_tokens | default 0)
        if $limits.max_cost_usd != null and $usage.cost_usd == null and not $warned_cost {
            warn "max_cost_usd is set but this endpoint does not report call costs, so only token budgets are enforced"
            $warned_cost = true
        }
        $ctx = (emit $ctx "model.end" ($model_fields | merge {
            ok: true, usage: $step.usage, cost: $step.cost, finish_reason: $step.finish_reason, retries: $step.retries, error: ""
            content: { response: $step.raw }
        }))

        let message = $step.message
        let calls = ($message | get -o tool_calls | default [])
        let iter_end = { span_id: $iter_span, parent_span_id: $run_span, start_ns: $iter_start, iteration: $turn, finish_reason: $step.finish_reason, error: "" }

        if ($calls | is-empty) {
            $messages = ($messages | append $message)
            $answer = $message.content
            $status = (if $step.finish_reason == "length" { "truncated" } else { "done" })
            $ctx = (flush (emit $ctx "iteration.end" $iter_end))
            break
        }

        # Out of iterations and still asking for tools: don't run them (the
        # conversation would be left holding calls without results), just
        # report whatever text came with them.
        if $turn == $agent.max_iterations {
            $answer = $message.content
            $ctx = (flush (emit $ctx "iteration.end" $iter_end))
            break
        }

        if $message.content != null {
            $last_content = $message.content
        }
        $messages = ($messages | append $message)
        for call in $calls {
            let step = (tool-step $agent $call $ctx $iter_span $depth $limits $usage)
            $ctx = $step.ctx
            $messages = ($messages | append $step.message)
            if $step.child != null {
                $children = ($children | append $step.child)
                $usage = (merge-usage $usage $step.child.usage)
            }
        }

        # The round is complete -- every call has its result -- so this is a
        # state a resumed run can safely start from.
        let saved = (snapshot $sess $messages "running" $base_total $usage)
        $sess = $saved.sess
        $ctx = (flush (emit $ctx "iteration.end" $iter_end))
        if $saved.error != "" {
            $status = "error"
            $error = $saved.error
            break
        }
    }

    let final = (snapshot $sess $messages $status $base_total $usage)
    if $final.error != "" and $status != "error" {
        $status = "error"
        $error = $final.error
    }
    $ctx = (emit $ctx "run.end" {
        span_id: $run_span, parent_span_id: $ctx.parent_span_id, start_ns: $run_start
        runtime: $agent.runtime, model: $agent.model
        status: $status, iterations: $turns, usage: $usage, error: $error
        content: { answer: $answer }
    })
    $ctx = (flush $ctx)

    { status: $status, answer: $answer, error: $error, messages: $messages, usage: $usage, iterations: $turns, subagents: $children, run_id: $ctx.run_id, journal: $ctx.journal, session: $session }
}
