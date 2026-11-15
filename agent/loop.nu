# The agent loop: call the model, run the tools it asks for, repeat until it
# answers. One entry point, `run-agent`, and it always returns a record:
#
#   {
#     status: "done" | "truncated" | "max_turns" | "error"
#     answer: string | null     # the model's final text, if it produced any
#     error: string             # what went wrong, when status is "error"
#     messages: list            # the whole conversation, system prompt included
#     usage: { prompt_tokens, completion_tokens, total_tokens, calls, cost_usd }
#     iterations: int           # model calls made
#   }
#
#   done       the model finished its answer
#   truncated  the model hit its output limit mid-answer (`answer` is the part
#              it wrote) -- raise max_tokens
#   max_turns  the model was still calling tools when it ran out of iterations;
#              the last turn asks it to answer from what it has gathered, so
#              `answer` is usually still set
#   error      a model call failed after its retries (`error` says why);
#              `messages` holds everything up to that point
#
# run-agent does not raise for model or tool failures -- a tool failure is fed
# back to the model as text, a model failure is a status -- so a caller can
# always inspect what happened.
use ../common/otel.nu *
use ../tools/runtime.nu *

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

# One model call, wrapped in a "gen_ai.chat" span with token-usage and duration
# metrics. Returns { message, finish_reason, usage, cost, retries }; raises if
# the call fails.
def model-step [agent: record, parent: record] {
    let provider = (otel-provider-name $agent.runtime)
    let attrs = { "gen_ai.operation.name": "chat", "gen_ai.provider.name": $provider, "gen_ai.request.model": $agent.model }
    let start_ns = (now-ns)
    let span = (otel-start-span "gen_ai.chat" $parent $attrs)

    let result = (try {
        do $agent.model_call $agent.messages
    } catch {|e|
        otel-end-span $span { "error.type": "_OTHER" } $e.msg [(otel-exception-event "_OTHER" $e.msg)]
        error make { msg: $e.msg }
    })
    let choice = ($result | get -o choices.0)
    if $choice == null {
        let msg = "the provider returned no choices"
        otel-end-span $span { "error.type": "_OTHER" } $msg [(otel-exception-event "_OTHER" $msg)]
        error make { msg: $msg }
    }

    let usage = ($result | get -o usage | default {})
    let input_tokens = ($usage | get -o prompt_tokens | default 0)
    let output_tokens = ($usage | get -o completion_tokens | default 0)
    let cost = ($result | get -o cost | default {})

    # One line per model call for whoever wants to total up a run's cost: set
    # AGENT_COST_FILE and every call appends a JSON record (cost fields are
    # null unless the endpoint is a proxy that reports them). Best effort: a
    # failure here must never fail the call itself.
    let cost_file = ($env.AGENT_COST_FILE? | default "")
    if ($cost_file | is-not-empty) {
        try {
            ({
                agent: $agent.name
                model: $agent.model
                input_tokens: $input_tokens
                output_tokens: $output_tokens
                cost_usd: ($cost | get -o cost_usd | default null)
                key_spend: ($cost | get -o key_spend | default null)
                key_max_budget: ($cost | get -o key_max_budget | default null)
            } | to json --raw) + "\n" | save --append $cost_file
        } catch {|e| print --stderr $"warning: could not record this call's cost: ($e.msg)" }
    }

    let duration_s = (((now-ns) - $start_ns) | into float) / 1_000_000_000.0
    otel-record-histogram "gen_ai.client.token.usage" "{token}" ($input_tokens | into float) ($attrs | insert "gen_ai.token.type" "input")
    otel-record-histogram "gen_ai.client.token.usage" "{token}" ($output_tokens | into float) ($attrs | insert "gen_ai.token.type" "output")
    otel-record-histogram "gen_ai.client.operation.duration" "s" $duration_s $attrs
    otel-end-span $span {
        "gen_ai.usage.input_tokens": $input_tokens
        "gen_ai.usage.output_tokens": $output_tokens
        "retry_count": ($result | get -o retry_attempts | default 1)
    }
    # The raw reply goes to the OTel logs signal, correlated to its span.
    otel-send-log ($result | to json) $attrs "info" { trace_id: $span.trace_id, span_id: $span.span_id }
    if ($env.AGENT_LOG? != null and ($env.AGENT_LOG | into bool)) {
        print --stderr ($result | to json)
    }

    { message: $choice.message, finish_reason: ($choice.finish_reason? | default "stop"), usage: $usage, cost: $cost }
}

# Run one tool call under an "execute_tool" span (per OpenTelemetry's GenAI
# semantic conventions). Arguments and results are recorded on the span only
# when OTEL_CAPTURE_TOOL_CONTENT is on -- the spec flags both as possibly
# sensitive. Returns the "tool" message to append to the conversation.
# run-tool never raises: a failed tool is a result the model gets to see, and
# the span is marked ERROR.
def tool-step [agent: record, call: record, parent: record] {
    let name = $call.function.name
    mut attrs = { "gen_ai.operation.name": "execute_tool", "gen_ai.tool.name": $name }
    if ($call.id? | is-not-empty) {
        $attrs = ($attrs | insert "gen_ai.tool.call.id" $call.id)
    }
    if (otel-capture-tool-content) {
        $attrs = ($attrs | insert "gen_ai.tool.call.arguments" ($call.function.arguments | if ($in | describe) == "string" { $in } else { to json }))
    }
    let span = (otel-start-span $"execute_tool ($name)" $parent $attrs)
    let result = (run-tool $agent.tools $call.function)
    let text = (tool-result-text $result)
    if $result.ok {
        otel-end-span $span (if (otel-capture-tool-content) { { "gen_ai.tool.call.result": $text } } else { {} })
        otel-record-counter "agent.tool.call.count" "{call}" 1.0 { "gen_ai.tool.name": $name, "status": "ok" }
    } else {
        otel-end-span $span { "error.type": "tool_error" } $result.error [(otel-exception-event "tool_error" $result.error)]
        otel-record-counter "agent.tool.call.count" "{call}" 1.0 { "gen_ai.tool.name": $name, "status": "error" }
    }
    { role: "tool", name: $name, content: $text, tool_call_id: ($call.id? | default "") }
}

# Run the agent on `query` (piped-in agent record, from `agent`). `--parent` is
# an OTel span context to nest this run's spans under; without it the run
# starts a new trace.
export def run-agent [query: string, --parent: record = {}] {
    let agent = $in
    let provider = (otel-provider-name $agent.runtime)
    let counter_attrs = { "gen_ai.provider.name": $provider, "gen_ai.request.model": $agent.model }
    let run_span = (otel-start-span "agent.run" $parent { "gen_ai.agent.name": $agent.name })

    mut messages = ($agent.messages | append { role: "user", content: $query })
    mut usage = (zero-usage)
    mut status = "max_turns"
    mut answer: any = null
    mut error = ""
    mut turns = 0

    for turn in 1..$agent.max_iterations {
        $turns = $turn
        # On the last permitted iteration, ask for the answer instead of letting
        # the agent spend it on another tool call.
        if $turn == $agent.max_iterations and $turn > 1 {
            $messages = ($messages | append { role: "user", content: $FINAL_TURN_PROMPT })
        }
        let iter_span = (otel-start-span "agent.iteration" $run_span { "iteration": $turn })

        let step = (try {
            model-step ($agent | upsert messages $messages) $iter_span
        } catch {|e|
            { failed: $e.msg }
        })
        if "failed" in $step {
            otel-end-span $iter_span { "error.type": "_OTHER" } $step.failed
            $status = "error"
            $error = $step.failed
            break
        }
        $usage = (add-usage $usage $step)

        let message = $step.message
        let calls = ($message | get -o tool_calls | default [])
        otel-end-span $iter_span { "finish_reason": $step.finish_reason }

        if ($calls | is-empty) {
            $messages = ($messages | append $message)
            $answer = $message.content
            $status = (if $step.finish_reason == "length" { "truncated" } else { "done" })
            break
        }

        # Out of iterations and still asking for tools: don't run them (the
        # conversation would be left holding calls without results), just
        # report whatever text came with them.
        if $turn == $agent.max_iterations {
            $answer = $message.content
            break
        }

        $messages = ($messages | append $message)
        for call in $calls {
            $messages = ($messages | append (tool-step $agent $call $iter_span))
        }
    }

    otel-end-span $run_span { "iterations": $turns, "status": $status, "max_iterations_reached": ($status == "max_turns") } (if $status == "error" { $error } else { "" })
    otel-record-counter "agent.iteration.count" "{iteration}" ($turns | into float) $counter_attrs

    { status: $status, answer: $answer, error: $error, messages: $messages, usage: $usage, iterations: $turns }
}
