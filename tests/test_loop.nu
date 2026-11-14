# The agent loop, driven by the offline mock provider.
use std/assert
use lib.nu *
use ../agent/agents.nu [agent, run_agent]
use ../agent/internal.nu [call]

export def test-answers-directly [] {
    let tools = (make-tools)
    let answer = (agent (mock-agent-config ["hello there"] $tools) | run_agent "hi")
    assert equal $answer "hello there"
}

export def test-runs-tool-then-answers [] {
    let tools = (make-tools)
    let responses = [{ tool_calls: [{ name: "echo_tool", arguments: { text: "x" } }] } "all done"]
    let answer = (agent (mock-agent-config $responses $tools) | run_agent "go")
    assert equal $answer "all done"
}

export def test-tool-result-is-fed-back-as-a-tool-message [] {
    let tools = (make-tools)
    let responses = [{ tool_calls: [{ name: "echo_tool", arguments: { text: "x" } }] } "all done"]
    let a = (agent (mock-agent-config $responses $tools))
    let step = (call $a "go")
    let tool_msg = ($step.agent.messages | last)
    assert equal $tool_msg.role "tool"
    assert equal $tool_msg.name "echo_tool"
    assert equal $tool_msg.tool_call_id "call_0_0"
    assert equal ($tool_msg.content | str trim) "echo:x"
}

export def test-parallel-tool-calls-each-get-a-result [] {
    let tools = (make-tools)
    let responses = [{ tool_calls: [{ name: "echo_tool", arguments: { text: "a" } }, { name: "echo_tool", arguments: { text: "b" } }] } "ok"]
    let step = (call (agent (mock-agent-config $responses $tools)) "go")
    let results = ($step.agent.messages | where role == "tool" | each {|m| $m.content | str trim })
    assert equal $results ["echo:a" "echo:b"]
}

export def test-unknown-runtime-is-an-error [] {
    let msg = (error-of { agent { runtime: "nope", model: "m" } })
    assert ($msg | str contains "Unknown runtime 'nope'")
}
