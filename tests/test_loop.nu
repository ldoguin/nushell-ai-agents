# The agent loop, driven by the offline mock provider.
use std/assert
use lib.nu *
use ../agent/agents.nu [agent]
use ../agent/loop.nu [run-agent]

def go [responses: list, query: string = "go", extra: record = {}] {
    let tools = (make-tools)
    agent ((mock-agent-config $responses $tools) | merge $extra) | run-agent $query
}

def tool-call [name: string, arguments: record = {}] {
    { tool_calls: [{ name: $name, arguments: $arguments }] }
}

export def test-answers-directly [] {
    let r = (go ["hello there"])
    assert equal $r.status "done"
    assert equal $r.answer "hello there"
    assert equal $r.error ""
    assert equal $r.iterations 1
    assert equal ($r.messages | get role) ["user" "assistant"]
}

export def test-runs-tool-then-answers [] {
    let r = (go [(tool-call echo_tool { text: "x" }) "all done"])
    assert equal $r.status "done"
    assert equal $r.answer "all done"
    assert equal $r.iterations 2
    assert equal ($r.messages | get role) ["user" "assistant" "tool" "assistant"]
}

export def test-tool-result-is-fed-back-as-a-tool-message [] {
    let r = (go [(tool-call echo_tool { text: "x" }) "ok"])
    let tool_msg = ($r.messages | where role == "tool" | first)
    assert equal $tool_msg { role: "tool", name: "echo_tool", content: "echo:x", tool_call_id: "call_0_0" }
}

export def test-parallel-tool-calls-each-get-a-result [] {
    let calls = { tool_calls: [{ name: "echo_tool", arguments: { text: "a" } }, { name: "echo_tool", arguments: { text: "b" } }] }
    let r = (go [$calls "ok"])
    assert equal ($r.messages | where role == "tool" | get content) ["echo:a" "echo:b"]
    assert equal ($r.messages | where role == "tool" | get tool_call_id) ["call_0_0" "call_0_1"]
}

export def test-system-prompt-leads-the-conversation [] {
    let tools = (make-tools)
    "You are terse." | save ($tools.dir | path join prompt.txt)
    let cfg = ((mock-agent-config ["hi"] $tools) | insert prompt ($tools.dir | path join prompt.txt))
    let r = (agent $cfg | run-agent "go")
    assert equal ($r.messages | first) { role: "system", content: "You are terse." }
}

export def test-failing-tool-reaches-the-model-as-an-error-string [] {
    let r = (go [(tool-call fail_tool) "sorry about that"])
    let tool_msg = ($r.messages | where role == "tool" | first)
    assert equal ($tool_msg.content | describe) "string" "a failed tool must not put a record into the conversation"
    assert ($tool_msg.content | str starts-with "Error: ")
    assert ($tool_msg.content | str contains "boom")
    # and the loop carries on to the model's recovery
    assert equal $r.status "done"
    assert equal $r.answer "sorry about that"
}

export def test-unknown-tool-call-is-recoverable [] {
    let r = (go [(tool-call injected) "ok, never mind"])
    let tool_msg = ($r.messages | where role == "tool" | first)
    assert ($tool_msg.content | str contains "Unknown tool 'injected'")
    assert (not ($tool_msg.content | str contains "SHOULD NOT RUN"))
    assert equal $r.status "done"
}

export def test-tool-policy-comes-from-config [] {
    let r = (go [(tool-call echo_tool { text: "x" }) "done"] "go" { tool_policy: { echo_tool: "deny" } })
    assert (($r.messages | where role == "tool" | first | get content) | str contains "not permitted")
}

# ------------------------------------------------------------ outcomes

export def test-max-turns-when-the-model-never-stops-calling-tools [] {
    let r = (go [(tool-call echo_tool { text: "1" }) (tool-call echo_tool { text: "2" }) (tool-call echo_tool { text: "3" })] "go" { max_iterations: 3 })
    assert equal $r.status "max_turns"
    assert equal $r.iterations 3
    assert equal $r.answer null
    # the last turn was told to wrap up...
    assert ($r.messages | where role == "user" | last | get content | str contains "tool budget")
    # ...and its tool calls were not run, so no call is left without a result
    let calls = ($r.messages | where role == "assistant" | get tool_calls | flatten | length)
    assert equal $calls ($r.messages | where role == "tool" | length)
}

export def test-final-turn-asks-for-an-answer-and-gets-one [] {
    let r = (go [(tool-call echo_tool { text: "1" }) (tool-call echo_tool { text: "2" }) "here is what I found"] "go" { max_iterations: 3 })
    assert equal $r.status "done"
    assert equal $r.answer "here is what I found"
    assert equal $r.iterations 3
}

export def test-single-iteration-budget-does-not-add-the-wrap-up-prompt [] {
    let r = (go ["quick"] "go" { max_iterations: 1 })
    assert equal $r.status "done"
    assert equal ($r.messages | where role == "user" | length) 1
}

export def test-truncated-answer-is-reported [] {
    let r = (go [{ content: "partial ans", finish_reason: "length" }])
    assert equal $r.status "truncated"
    assert equal $r.answer "partial ans"
}

export def test-model-failure-is-a-status-not-a-crash [] {
    let r = (go [(tool-call echo_tool { text: "x" }) { error: "provider exploded" }])
    assert equal $r.status "error"
    assert ($r.error | str contains "provider exploded")
    assert equal $r.answer null
    assert equal $r.iterations 2
    # everything up to the failure is kept
    assert equal ($r.messages | get role) ["user" "assistant" "tool"]
}

export def test-usage-is-summed-across-calls [] {
    let r = (go [(tool-call echo_tool { text: "x" }) "done"])
    assert equal $r.usage { prompt_tokens: 20, completion_tokens: 10, total_tokens: 30, calls: 2, cost_usd: null }
}

export def test-conversation-can-be-continued-from-returned-messages [] {
    let tools = (make-tools)
    let a = (agent (mock-agent-config ["first answer" "second answer"] $tools))
    let one = ($a | run-agent "q1")
    let two = ($a | upsert messages $one.messages | run-agent "q2")
    assert equal $two.answer "second answer"
    assert equal ($two.messages | get content | first 4) ["q1" "first answer" "q2" "second answer"]
}
