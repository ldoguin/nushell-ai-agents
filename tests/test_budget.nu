# Budgets in the loop: token and cost limits, shared with sub-agents.
use std/assert
use lib.nu *
use ../agent/agents.nu [agent]
use ../agent/loop.nu [run-agent]
use ../agent/registry.nu [get-agent]
use ../agent/journal.nu [read-journal]
use ../agent/session.nu [load-session]
use ../agent.nu [agent-ask]

def tool-call [name: string, arguments: record = {}, extra: record = {}] {
    { tool_calls: [{ name: $name, arguments: $arguments }] } | merge $extra
}

# Each mock model call uses 15 tokens. `extra` is merged into the agent config.
def go [responses: list, extra: record = {}] {
    let t = (make-tools)
    agent ((mock-agent-config $responses $t) | merge $extra) --name tester | run-agent "go"
}

# ----------------------------------------------------------------- tokens

export def test-a-run-stops-once-its-token-budget-is-used [] {
    # call 1 = 15 tokens, call 2 = 30 >= 20: the third call must not happen
    let r = (go [
        (tool-call echo_tool { text: "1" } { content: "thinking aloud" })
        (tool-call echo_tool { text: "2" })
        "never reached"
    ] { max_total_tokens: 20 })
    assert equal $r.status "budget_exceeded"
    assert equal $r.iterations 2
    assert equal $r.usage.calls 2
    assert equal $r.usage.total_tokens 30
    assert equal $r.answer "thinking aloud" "the latest text the model produced alongside its tool calls"
    assert equal $r.error ""
    # the conversation is intact: every call has its result
    assert equal ($r.messages | get role) ["user" "assistant" "tool" "assistant" "tool"]
}

export def test-a-budget-that-is-not-reached-changes-nothing [] {
    let r = (go [(tool-call echo_tool { text: "1" }) "done"] { max_total_tokens: 1000 })
    assert equal $r.status "done"
    assert equal $r.answer "done"
}

export def test-the-budget-is-checked-before-a-call-not-after-an-answer [] {
    # a single call that overshoots the budget still delivers its answer
    let r = (go ["the answer"] { max_total_tokens: 5 })
    assert equal $r.status "done"
    assert equal $r.answer "the answer"
    assert equal $r.usage.total_tokens 15
}

export def test-budget-events-and-saved-status [] {
    let t = (make-tools)
    let r = (with-env { AGENT_SINKS: "jsonl", AGENT_LOG_DIR: ($t.dir | path join logs), AGENT_SESSION_DIR: ($t.dir | path join sessions) } {
        agent ((mock-agent-config [(tool-call echo_tool { text: "1" }) (tool-call echo_tool { text: "2" }) "never"] $t) | merge { max_total_tokens: 20 }) --name tester | run-agent "go" --session s1
    })
    let e = (read-journal $r.journal)
    assert equal ($e | where type == "budget.exceeded" | first | select limit used max) { limit: "max_total_tokens", used: 30, max: 20 }
    assert equal ($e | where type == "run.end" | first | get status) "budget_exceeded"
    assert equal (with-env { AGENT_SESSION_DIR: ($t.dir | path join sessions) } { load-session s1 | get status }) "budget_exceeded"
}

# -------------------------------------------------------------------- cost

export def test-a-cost-budget-uses-the-cost-the-provider-reports [] {
    let r = (go [
        (tool-call echo_tool { text: "1" } { cost_usd: 0.01 })
        (tool-call echo_tool { text: "2" } { cost_usd: 0.01 })
        "never"
    ] { max_cost_usd: 0.015 })
    assert equal $r.status "budget_exceeded"
    assert equal $r.iterations 2
    assert equal $r.usage.cost_usd 0.02
}

export def test-a-cost-budget-without-cost-reporting-warns-and-token-budgets-still-work [] {
    let repo = ($env.FILE_PWD | path dirname)
    let t = (make-tools)
    let script = $"use '($repo)/agent/agents.nu' [agent]; use '($repo)/agent/loop.nu' [run-agent]; let r = \(agent {runtime: 'mock', responses: [{tool_calls: [{name: 'echo_tool', arguments: {text: 'a'}}]}, {tool_calls: [{name: 'echo_tool', arguments: {text: 'b'}}]}, 'never'], model_tools: '($t.schema)', tool_functions: '($t.functions)', max_cost_usd: 5.0, max_total_tokens: 20} --name x | run-agent 'go'\); print $r.status"
    let out = (^nu --no-config-file -c $script | complete)
    assert equal $out.exit_code 0 $out.stderr
    assert ($out.stderr | str contains "max_cost_usd is set but this endpoint does not report call costs")
    assert equal ($out.stderr | split row "does not report" | length) 2 "warned once, not on every call"
    assert equal ($out.stdout | str trim) "budget_exceeded" "the token budget still applied"
}

# ------------------------------------------------------------ sub-agents

export def test-sub-agent-usage-counts-against-the-parents-budget [] {
    # parent call 15 + helper 15 = 30; parent call 2 -> 45 >= 40, so the second delegation is refused
    let m = (write-team {
        parent: { runtime: "mock", agents: ["helper"], max_total_tokens: 40, responses: [
            (tool-call helper { query: "q1" })
            (tool-call helper { query: "q2" })
            "never"
        ] }
        helper: { runtime: "mock", responses: ["helped"] }
    })
    let r = (get-agent parent --manifest $m | run-agent "go")
    assert equal $r.status "budget_exceeded"
    assert equal ($r.subagents | length) 1 "the second delegation did not run"
    assert ($r.messages | where role == "tool" | last | get content | str contains "budget is used up")
    assert equal $r.usage.total_tokens 45
}

export def test-a-sub-agent-gets-only-what-is-left-of-its-callers-budget [] {
    # the parent has 20 tokens and has used 15, so the looping helper has 5: one call, then it must stop
    let m = (write-team {
        parent: { runtime: "mock", agents: ["looper"], max_total_tokens: 20, responses: [(tool-call looper { query: "go" }) "parent finishes"] }
        looper: { runtime: "mock", tools: true, responses: [
            (tool-call echo_tool { text: "1" })
            (tool-call echo_tool { text: "2" })
            (tool-call echo_tool { text: "3" })
            "never"
        ] }
    })
    let r = (get-agent parent --manifest $m | run-agent "go")
    assert equal $r.subagents.0.status "budget_exceeded"
    assert equal $r.subagents.0.iterations 1
    assert ($r.messages | where role == "tool" | first | get content | str contains "ran out of budget without producing an answer")
}

export def test-a-sub-agent-can-have-a-tighter-budget-of-its-own [] {
    let m = (write-team {
        parent: { runtime: "mock", agents: ["frugal"], responses: [(tool-call frugal { query: "go" }) "ok"] }
        frugal: { runtime: "mock", tools: true, max_total_tokens: 10, responses: [
            (tool-call echo_tool { text: "1" } { content: "partial result" })
            (tool-call echo_tool { text: "2" })
            "never"
        ] }
    })
    let r = (get-agent parent --manifest $m | run-agent "go")
    assert equal $r.status "done" "the parent was not constrained"
    assert equal $r.subagents.0.status "budget_exceeded"
    assert ($r.messages | where role == "tool" | first | get content | str contains "[Note: sub-agent 'frugal' ran out of budget")
    assert ($r.messages | where role == "tool" | first | get content | str contains "partial result")
}

# ------------------------------------------------------------- entry point

export def test-agent-ask-returns-the-partial-answer-for-an-exhausted-budget [] {
    let m = (write-team { a: { runtime: "mock", tools: true, max_total_tokens: 20, responses: [
        (tool-call echo_tool { text: "1" } { content: "so far so good" })
        (tool-call echo_tool { text: "2" })
        "never"
    ] } })
    assert equal (agent-ask "q" --agent a --manifest $m) "so far so good"
    assert equal (agent-ask "q" --agent a --manifest $m --full | get status) "budget_exceeded"
}
