# The top-level entry points in agent.nu.
use std/assert
use lib.nu *
use ../agent.nu [agent-ask, agent-list]

def manifest [agents: record] {
    let dir = (temp-dir)
    let file = ($dir | path join agents.json)
    $agents | to json | save $file
    $file
}

export def test-asks-the-named-agent [] {
    let m = (manifest { a: { runtime: "mock", responses: ["from a"] }, b: { runtime: "mock", responses: ["from b"] } })
    assert equal (agent-ask "q" --agent b --manifest $m) "from b"
}

export def test-unknown-agent-is-named-not-confused-with-no-agent [] {
    let m = (manifest { a: { runtime: "mock", responses: ["x"] }, b: { runtime: "mock", responses: ["y"] } })
    assert ((error-of { agent-ask "q" --agent nope --manifest $m }) | str contains "No agent named 'nope'")
}

export def test-agent-can-be-implied [] {
    let one = (manifest { only: { runtime: "mock", responses: ["the one"] } })
    assert equal (agent-ask "q" --manifest $one) "the one"
    let two = (manifest { a: { runtime: "mock", responses: ["x"] }, b: { runtime: "mock", responses: ["y"] } })
    assert ((error-of { agent-ask "q" --manifest $two }) | str contains "Choose an agent")
    assert equal (with-env { AGENT_NAME: "b" } { agent-ask "q" --manifest $two }) "y"
}

export def test-piped-text-is-appended-to-the-question [] {
    let m = (manifest { a: { runtime: "mock", responses: ["ok"] } })
    let r = ("the text" | agent-ask "summarize:" --agent a --manifest $m --full)
    assert equal ($r.messages | first | get content) "summarize: the text"
}

export def test-failed-run-raises-unless-full-is-asked-for [] {
    let m = (manifest { a: { runtime: "mock", responses: [{ error: "provider down" }] } })
    let msg = (error-of { agent-ask "q" --agent a --manifest $m })
    assert ($msg | str contains "Agent 'a' failed: provider down")
    let r = (agent-ask "q" --agent a --manifest $m --full)
    assert equal $r.status "error"
}

export def test-lists-agents [] {
    let m = (manifest { a: { runtime: "mock", description: "first" } })
    assert equal (agent-list --manifest $m | get name) ["a"]
}
