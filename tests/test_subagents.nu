# Agents calling other agents as tools.
use std/assert
use lib.nu *
use ../agent/registry.nu [get-agent]
use ../agent/agents.nu [agent]
use ../agent/loop.nu [run-agent]

# Write a manifest (next to the shared test tools) and return its path. Entries
# that say `tools: true` get the echo/fail/... test tools.
def team [agents: record] {
    let t = (make-tools)
    let resolved = ($agents | items {|name, cfg|
        let base = ($cfg | reject -o tools)
        let full = (if ($cfg | get -o tools | default false) { $base | merge { model_tools: "tools.json", tool_functions: "tools.nu" } } else { $base })
        { k: $name, v: $full }
    } | reduce --fold {} {|e, acc| $acc | insert $e.k $e.v })
    let file = ($t.dir | path join agents.json)
    $resolved | to json | save $file
    $file
}

def delegate [name: string, query: string] {
    { tool_calls: [{ name: $name, arguments: { query: $query } }] }
}

def run-team [m: string, name: string = "parent"] {
    get-agent $name --manifest $m | run-agent "go"
}

# ----------------------------------------------------------- delegation

export def test-parent-calls-a-subagent-and-uses-its-answer [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["helper"], responses: [(delegate helper "find x") "parent is done"] }
        helper: { runtime: "mock", description: "finds things", responses: ["found x"] }
    })
    let r = (run-team $m)
    assert equal $r.status "done"
    assert equal $r.answer "parent is done"
    assert equal ($r.messages | where role == "tool" | first | get content) "found x"
    assert equal ($r.subagents | select name status iterations) [{ name: "helper", status: "done", iterations: 1 }]
}

export def test-subagent-receives-the-query-on-a-fresh-conversation [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["echoer"], responses: [(delegate echoer "the secret question") "ok"] }
        echoer: { runtime: "mock", responses: ["you asked: {{last_user}}"] }
    })
    let r = (run-team $m)
    assert equal ($r.messages | where role == "tool" | first | get content) "you asked: the secret question"
}

export def test-usage-includes-subagents [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["helper"], responses: [(delegate helper "q") "done"] }
        helper: { runtime: "mock", responses: ["a"] }
    })
    let r = (run-team $m)
    # the parent made 2 model calls and the helper 1, 15 tokens each
    assert equal $r.usage.calls 3
    assert equal $r.usage.total_tokens 45
    assert equal $r.iterations 2 "iterations counts this agent's own calls"
    assert equal $r.subagents.0.usage.calls 1
}

export def test-subagent-uses-its-own-tools [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["worker"], responses: [(delegate worker "go") "ok"] }
        worker: { runtime: "mock", tools: true, responses: [{ tool_calls: [{ name: "echo_tool", arguments: { text: "from worker" } }] } "worker saw it"] }
    })
    let r = (run-team $m)
    assert equal ($r.messages | where role == "tool" | first | get content) "worker saw it"
    assert equal $r.subagents.0.iterations 2
}

export def test-subagents-can-call-subagents [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["mid"], responses: [(delegate mid "q") "p"] }
        mid: { runtime: "mock", agents: ["leaf"], responses: [(delegate leaf "q") "m"] }
        leaf: { runtime: "mock", responses: ["l"] }
    })
    let r = (run-team $m)
    assert equal ($r.subagents | get name) ["mid"]
    assert equal ($r.subagents.0.subagents | get name) ["leaf"]
    assert equal $r.usage.calls 5
}

# ------------------------------------------------------------- schema

export def test-subagent-tool-schema-is-synthesized [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["helper"], tools: true, responses: [] }
        helper: { runtime: "mock", description: "finds things", responses: [] }
    })
    let a = (get-agent parent --manifest $m)
    let names = ($a.tool_schema | get function.name)
    assert equal $names ["echo_tool" "record_tool" "fail_tool" "slow_tool" "helper"]
    let tool = ($a.tool_schema | last)
    assert equal $tool.type "function"
    assert ($tool.function.description | str contains "finds things")
    assert equal $tool.function.parameters.required ["query"]
    assert equal $tool.function.parameters.properties.query.type "string"
    assert equal $a.tools.subagents ["helper"]
}

export def test-unknown-tool-message-offers-subagents [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["helper"], responses: [{ tool_calls: [{ name: "nope", arguments: {} }] } "ok"] }
        helper: { runtime: "mock", responses: [] }
    })
    let r = (run-team $m)
    assert ($r.messages | where role == "tool" | first | get content | str contains "Available tools: helper")
}

# --------------------------------------------------------- failure modes

export def test-subagent-failure-reaches-the-parent-as-an-error [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["flaky"], responses: [(delegate flaky "q") "recovered"] }
        flaky: { runtime: "mock", responses: [{ error: "provider down" }] }
    })
    let r = (run-team $m)
    let msg = ($r.messages | where role == "tool" | first | get content)
    assert ($msg | str starts-with "Error: Sub-agent 'flaky' failed: provider down")
    assert equal $r.status "done"
    assert equal $r.subagents.0.status "error"
}

export def test-incomplete-subagent-answers-are-flagged [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["slowpoke"], responses: [(delegate slowpoke "q") "ok"] }
        slowpoke: { runtime: "mock", tools: true, max_iterations: 2, responses: [
            { tool_calls: [{ name: "echo_tool", arguments: { text: "1" } }] }
            { content: "best effort", tool_calls: [{ name: "echo_tool", arguments: { text: "2" } }] }
        ] }
    })
    let r = (run-team $m)
    let msg = ($r.messages | where role == "tool" | first | get content)
    assert ($msg | str contains "[Note: sub-agent 'slowpoke' ran out of iterations; its answer may be incomplete]")
    assert ($msg | str contains "best effort")
    assert equal $r.subagents.0.status "max_turns"
}

export def test-subagent-that-gives-no-answer-is-an-error [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["mute"], responses: [(delegate mute "q") "ok"] }
        mute: { runtime: "mock", tools: true, max_iterations: 2, responses: [
            { tool_calls: [{ name: "echo_tool", arguments: { text: "1" } }] }
            { tool_calls: [{ name: "echo_tool", arguments: { text: "2" } }] }
        ] }
    })
    let msg = (run-team $m | get messages | where role == "tool" | first | get content)
    assert ($msg | str contains "ran out of iterations without producing an answer")
}

export def test-nesting-depth-is-limited [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["b"], responses: [(delegate b "q") "a done"] }
        b: { runtime: "mock", agents: ["c"], responses: [(delegate c "q") "b done"] }
        c: { runtime: "mock", responses: ["c done"] }
    })
    let shallow = (with-env { AGENT_MAX_DEPTH: "1" } { run-team $m })
    assert equal ($shallow.subagents | get name) ["b"]
    assert equal $shallow.subagents.0.subagents [] "c is one level too deep and must not run"
    assert equal $shallow.status "done"

    let deep = (with-env { AGENT_MAX_DEPTH: "3" } { run-team $m })
    assert equal ($deep.subagents.0.subagents | get name) ["c"]
}

export def test-subagent-needs-a-query [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["helper"], responses: [{ tool_calls: [{ name: "helper", arguments: {} }] } "ok"] }
        helper: { runtime: "mock", responses: ["never"] }
    })
    let r = (run-team $m)
    assert ($r.messages | where role == "tool" | first | get content | str contains "needs a non-empty string argument 'query'")
    assert equal $r.subagents []
}

export def test-tool-policy-applies-to-subagents [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["helper"], tool_policy: { helper: "deny" }, responses: [(delegate helper "q") "ok"] }
        helper: { runtime: "mock", responses: ["never"] }
    })
    let r = (run-team $m)
    assert ($r.messages | where role == "tool" | first | get content | str contains "not permitted")
    assert equal $r.subagents []
}

# ------------------------------------------------------ rejected on load

export def test-cycles-are-rejected-on-load [] {
    let m = (team {
        a: { runtime: "mock", agents: ["b"] }
        b: { runtime: "mock", agents: ["c"] }
        c: { runtime: "mock", agents: ["a"] }
    })
    assert ((error-of { get-agent a --manifest $m }) | str contains "Agent cycle: a -> b -> c -> a")
    let selfish = (team { me: { runtime: "mock", agents: ["me"] } })
    assert ((error-of { get-agent me --manifest $selfish }) | str contains "Agent cycle: me -> me")
}

export def test-unknown-subagent-is-rejected-on-load [] {
    let m = (team { a: { runtime: "mock", agents: ["ghost"] }, b: { runtime: "mock" } })
    let msg = (error-of { get-agent a --manifest $m })
    assert ($msg | str contains "Agent 'a' lists agent 'ghost'")
    assert ($msg | str contains "Available: a, b")
}

export def test-a-broken-subagent-fails-the-parents-load [] {
    let m = (team {
        parent: { runtime: "mock", agents: ["broken"] }
        broken: { runtime: "mock", prompt: "missing.txt" }
    })
    assert ((error-of { get-agent parent --manifest $m }) | str contains "agent 'broken': 'prompt' file not found")
}

export def test-agents-key-is-validated [] {
    let m = (team {
        a: { runtime: "mock", agents: "helper" }
        b: { runtime: "mock", agents: ["x", "x"] }
        c: { runtime: "mock", agents: ["has space"] }
        d: { runtime: "mock", tools: true, agents: ["echo_tool"] }
        x: { runtime: "mock" }
        "has space": { runtime: "mock" }
        echo_tool: { runtime: "mock" }
    })
    assert ((error-of { get-agent a --manifest $m }) | str contains "'agents' must be a list")
    assert ((error-of { get-agent b --manifest $m }) | str contains "lists x more than once")
    assert ((error-of { get-agent c --manifest $m }) | str contains "'has space' is not usable as a tool name")
    assert ((error-of { get-agent d --manifest $m }) | str contains "both define a tool named echo_tool")
}

export def test-agents-need-a-manifest-to-resolve [] {
    let msg = (error-of { agent { runtime: "mock", agents: ["helper"] } --name solo })
    assert ($msg | str contains "was not built through a manifest")
}
