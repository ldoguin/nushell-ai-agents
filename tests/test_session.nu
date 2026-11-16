# Sessions: saving a conversation, continuing it, resuming after a crash.
use std/assert
use lib.nu *
use ../agent/agents.nu [agent]
use ../agent/loop.nu [run-agent]
use ../agent/registry.nu [get-agent]
use ../agent/session.nu [load-session, save-session, check-session-id]
use ../agent/journal.nu [read-journal]
use ../agent.nu [agent-ask, agent-sessions]

def tool-call [name: string, arguments: record = {}] {
    { tool_calls: [{ name: $name, arguments: $arguments }] }
}

# A fresh sessions directory and a tester agent with the given script.
def setup [responses: list, extra: record = {}] {
    let tools = (make-tools)
    {
        tools: $tools
        dir: ($tools.dir | path join sessions)
        agent: (agent ((mock-agent-config $responses $tools) | merge $extra) --name tester)
    }
}

def with-sessions [dir: string, action: closure] {
    with-env { AGENT_SESSION_DIR: $dir } { do $action }
}

# Every assistant message with tool calls is followed by a result for each call --
# the property providers insist on and a snapshot must never violate.
def assert-resumable [messages: list] {
    for m in ($messages | enumerate | where {|e| $e.item.role == "assistant" and ($e.item | get -o tool_calls | default [] | is-not-empty) }) {
        let ids = ($m.item.tool_calls | get id)
        let answered = ($messages | skip ($m.index + 1) | where role == "tool" | get tool_call_id)
        for id in $ids { assert ($id in $answered) $"tool call ($id) has no result" }
    }
}

# ------------------------------------------------------------ saving

export def test-a-session-is-saved-and-private [] {
    let s = (setup ["hello"])
    let r = (with-sessions $s.dir { $s.agent | run-agent "hi" --session s1 })
    assert equal $r.session "s1"
    let saved = (with-sessions $s.dir { load-session s1 })
    assert equal ($saved | select v id agent status runs) { v: 1, id: "s1", agent: "tester", status: "done", runs: 1 }
    assert equal ($saved.messages | get role) ["user" "assistant"]
    assert equal $saved.usage_total { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15, calls: 1, cost_usd: null }
    assert equal $saved.rev 2 "one snapshot at the start, one at the end"
    assert equal (glob $"($s.dir)/*.tmp-*") [] "no temp files left behind"
    if $nu.os-info.name != "windows" {
        assert equal (ls --long ($s.dir | path join s1.json) | get 0.mode) "rw-------"
        assert equal (ls --long --directory $s.dir | get 0.mode) "rwx------"
    }
}

export def test-a-run-without-a-session-writes-nothing [] {
    let s = (setup ["hello"])
    let r = (with-sessions $s.dir { $s.agent | run-agent "hi" })
    assert equal $r.session null
    assert (not ($s.dir | path exists))
}

export def test-a-session-continues-where-it-left-off [] {
    let s = (setup ["first answer" "second answer"])
    with-sessions $s.dir { $s.agent | run-agent "q1" --session s1 }
    let created = (with-sessions $s.dir { (load-session s1).created })
    let r = (with-sessions $s.dir { $s.agent | run-agent "q2" --session s1 })
    assert equal $r.answer "second answer"
    assert equal ($r.messages | get content) ["q1" "first answer" "q2" "second answer"]
    let saved = (with-sessions $s.dir { load-session s1 })
    assert equal $saved.runs 2
    assert equal $saved.usage_total.calls 2 "usage is cumulative across runs"
    assert equal $saved.usage_total.total_tokens 30
    assert equal $r.usage.calls 1 "but a run's own usage is just that run's"
    assert equal $saved.created $created
}

export def test-snapshots-never-leave-tool-calls-unanswered [] {
    # the second model call fails after a completed tool round
    let s = (setup [(tool-call echo_tool { text: "x" }) { error: "provider down" }])
    let r = (with-sessions $s.dir { $s.agent | run-agent "go" --session s1 })
    assert equal $r.status "error"
    let saved = (with-sessions $s.dir { load-session s1 })
    assert equal $saved.status "error"
    assert equal ($saved.messages | get role) ["user" "assistant" "tool"]
    assert-resumable $saved.messages
}

export def test-the-snapshot-advances-after-each-completed-tool-round [] {
    # `peek` reports how many messages the session file holds at the moment it runs,
    # so it sees the snapshots a crash at that point would have left behind
    let t = (make-tools)
    let dir = ($t.dir | path join sessions)
    let tools_file = ($t.dir | path join peek.nu)
    'def peek [args] { open $args.file | get messages | length | into string }' | save $tools_file
    let schema = ($t.dir | path join peek.json)
    [{ type: "function", function: { name: "peek", description: "d", parameters: { type: "object", properties: { file: { type: "string" } } } } }] | to json | save $schema
    let file = ($dir | path join s1.json)
    let a = (agent { runtime: "mock", model_tools: $schema, tool_functions: $tools_file, responses: [(tool-call peek { file: $file }) (tool-call peek { file: $file }) "done"] } --name tester)

    let r = (with-sessions $dir { $a | run-agent "go" --session s1 })
    let seen = ($r.messages | where role == "tool" | get content)
    # round 1 ran when only the question was saved; round 2 ran after round 1
    # (assistant message + its result) had been snapshotted: 1 + 2 = 3
    assert equal $seen ["1" "3"]
}

export def test-a-failed-run-resumes-without-retyping-the-question [] {
    let first = (setup [(tool-call echo_tool { text: "x" }) { error: "provider down" }])
    with-sessions $first.dir { $first.agent | run-agent "the original question" --session s1 }

    # the provider is back: same agent, a script that picks up after the tool round
    let again = (agent (mock-agent-config [(tool-call echo_tool { text: "x" }) "recovered"] $first.tools) --name tester)
    let r = (with-sessions $first.dir { $again | run-agent --session s1 --require-existing })
    assert equal $r.status "done"
    assert equal $r.answer "recovered"
    assert equal ($r.messages | get content | first) "the original question"
    assert equal ($r.messages | get role) ["user" "assistant" "tool" "assistant"]
    assert equal (with-sessions $first.dir { (load-session s1).status }) "done"
}

# --------------------------------------------------------------- guards

export def test-a-finished-session-needs-a-follow-up [] {
    let s = (setup ["done"])
    with-sessions $s.dir { $s.agent | run-agent "q" --session s1 }
    let msg = (error-of { with-sessions $s.dir { $s.agent | run-agent --session s1 } })
    assert ($msg | str contains "Session 's1' is complete")
}

export def test-session-guards [] {
    let s = (setup ["x"])
    with-sessions $s.dir { $s.agent | run-agent "q" --session s1 }
    let other = (agent (mock-agent-config ["y"] $s.tools) --name someone-else)
    assert ((error-of { with-sessions $s.dir { $other | run-agent "q" --session s1 } }) | str contains "belongs to agent 'tester', not 'someone-else'")
    assert ((error-of { with-sessions $s.dir { $s.agent | run-agent "q" --session nope --require-existing } }) | str contains "No session 'nope'")
    assert ((error-of { with-sessions $s.dir { $s.agent | run-agent } }) | str contains "Nothing to run")
    # without --require-existing an unknown id just starts a new session
    let r = (with-sessions $s.dir { (setup ["fresh"]).agent | run-agent "q" --session brand-new })
    assert equal $r.status "done"
}

export def test-session-ids-cannot-escape-the-directory [] {
    for bad in ["../x" "a/b" "" ".hidden" "has space" ("x" | fill --width 200 --character x) "-lead"] {
        let msg = (error-of { check-session-id $bad })
        assert ($msg | str contains "Invalid session id") $"should have rejected '($bad)'"
    }
    for good in ["a" "draft-1" "my.session_2" "A1"] {
        assert equal (check-session-id $good) $good
    }
}

export def test-unreadable-sessions-are-reported [] {
    let s = (setup ["x"])
    mkdir $s.dir
    "{ not json" | save ($s.dir | path join broken.json)
    '{"hello": "world"}' | save ($s.dir | path join other.json)
    assert ((error-of { with-sessions $s.dir { load-session broken } }) | str contains "unreadable")
    assert ((error-of { with-sessions $s.dir { load-session other } }) | str contains "corrupt")
    assert equal (with-sessions $s.dir { load-session absent }) null
}

# ------------------------------------------------------------ conflicts

export def test-stale-writes-are-refused [] {
    let s = (setup ["x"])
    let base = { id: "s1", agent: "tester", runtime: "mock", model: "", status: "running", rev: 0, created: "t", runs: 1, messages: [], usage_total: {} }
    with-sessions $s.dir {
        let one = (save-session $base)
        assert $one.ok
        assert equal $one.session.rev 1
        let two = (save-session $one.session)                   # a second process saves...
        assert equal $two.session.rev 2
        let stale = (save-session $one.session)                 # ...so this one's view is stale
        assert (not $stale.ok)
        assert $stale.conflict
        assert ($stale.error | str contains "modified by another process")
        assert equal (load-session s1 | get rev) 2 "nothing was overwritten"
    }
}

export def test-a-concurrent-writer-stops-the-run-instead-of-being-overwritten [] {
    let t = (make-tools)
    let dir = ($t.dir | path join sessions)
    let tools_file = ($t.dir | path join tamper.nu)
    'def tamper [args] { open $args.file | upsert rev 99 | save --force $args.file; "tampered" }' | save $tools_file
    let schema = ($t.dir | path join tamper.json)
    [{ type: "function", function: { name: "tamper", description: "d", parameters: { type: "object", properties: { file: { type: "string" } } } } }] | to json | save $schema
    let a = (agent { runtime: "mock", model_tools: $schema, tool_functions: $tools_file, responses: [(tool-call tamper { file: ($dir | path join s1.json) }) "done"] } --name tester)

    let r = (with-sessions $dir { $a | run-agent "go" --session s1 })
    assert equal $r.status "error"
    assert ($r.error | str contains "modified by another process")
    assert equal (open ($dir | path join s1.json) | get rev) 99 "the other writer's data is untouched"
}

# ---------------------------------------------------------- integration

export def test-sub-agent-runs-are-not-sessions [] {
    let t = (make-tools)
    let manifest = ($t.dir | path join agents.json)
    {
        parent: { runtime: "mock", agents: ["helper"], responses: [(tool-call helper { query: "q" }) "done"] }
        helper: { runtime: "mock", responses: ["helped"] }
    } | to json | save $manifest
    let dir = ($t.dir | path join sessions)
    with-sessions $dir { get-agent parent --manifest $manifest | run-agent "go" --session s1 }
    assert equal (glob $"($dir)/*.json" | length) 1
}

export def test-the-journal-records-which-session-a-run-belongs-to [] {
    let s = (setup ["hi"])
    let r = (with-env { AGENT_SESSION_DIR: $s.dir, AGENT_SINKS: "jsonl", AGENT_LOG_DIR: ($s.tools.dir | path join logs) } {
        $s.agent | run-agent "q" --session s1
    })
    assert equal (read-journal $r.journal | where type == "run.start" | first | get session) "s1"
}

export def test-agent-ask-sessions-and-resume [] {
    let t = (make-tools)
    let manifest = ($t.dir | path join agents.json)
    { writer: { runtime: "mock", responses: ["draft one" "draft two"] } } | to json | save $manifest
    let dir = ($t.dir | path join sessions)
    with-env { AGENT_SESSION_DIR: $dir } {
        assert equal (agent-ask "write" --agent writer --manifest $manifest --session d1) "draft one"
        # the agent defaults to the session's
        assert equal (agent-ask "shorten" --manifest $manifest --session d1) "draft two"
        assert equal (agent-sessions | select id agent status runs messages) [{ id: "d1", agent: "writer", status: "done", runs: 2, messages: 4 }]
        # the flags exclude each other, and --resume needs something to resume
        assert ((error-of { agent-ask "q" --manifest $manifest --session a --resume b }) | str contains "either --session or --resume")
        assert ((error-of { agent-ask --manifest $manifest --agent writer --resume nope }) | str contains "No session 'nope'")
        assert ((error-of { agent-ask --manifest $manifest --agent writer }) | str contains "Nothing to ask")
    }
}

# ------------------------------------------------------------- the crash

export def test-a-killed-run-resumes-from-its-session [] {
    let repo = ($env.FILE_PWD | path dirname)
    let t = (make-tools)
    let dir = ($t.dir | path join sessions)
    let crashy = ($t.dir | path join crashy.json)
    { crashy: { runtime: "mock", model_tools: "tools.json", tool_functions: "tools.nu", responses: [(tool-call slow_tool) "never reached"] } } | to json | save $crashy
    let script = $"use '($repo)/agent/registry.nu' [get-agent]; use '($repo)/agent/loop.nu' [run-agent]; get-agent crashy --manifest '($crashy)' | run-agent 'what is the answer' --session crash1 | ignore"

    # a run whose tool takes 5 seconds, killed -9 while it is inside the tool
    let logs = ($t.dir | path join logs)
    let pid = (with-env { AGENT_SESSION_DIR: $dir, AGENT_SINKS: "jsonl", AGENT_LOG_DIR: $logs } {
        ^bash -c $"nu --no-config-file -c \"($script)\" >/dev/null 2>&1 & echo $!" | str trim
    })
    mut waited = 0
    mut seen = false
    while not $seen {
        if $waited > 200 { ^kill -9 $pid; error make { msg: "the run never reached its tool call" } }
        sleep 50ms
        $waited += 1
        $seen = (($logs | path exists) and ((glob $"($logs)/*.jsonl" | is-not-empty)) and (open --raw (glob $"($logs)/*.jsonl" | first) | str contains "tool.start"))
    }
    ^kill -9 $pid
    sleep 200ms

    # what is on disk: the conversation up to the tool round that never finished
    let saved = (with-sessions $dir { load-session crash1 })
    assert equal $saved.status "running"
    assert equal ($saved.messages | get role) ["user"]
    assert-resumable $saved.messages

    # resume it, without retyping the question, with the agent as it is now
    let fixed = ($t.dir | path join fixed.json)
    { crashy: { runtime: "mock", responses: ["recovered after the crash"] } } | to json | save $fixed
    let answer = (with-env { AGENT_SESSION_DIR: $dir } { agent-ask --resume crash1 --manifest $fixed })
    assert equal $answer "recovered after the crash"
    let after = (with-sessions $dir { load-session crash1 })
    assert equal $after.status "done"
    assert equal ($after.messages | get content | first) "what is the answer"
    assert equal $after.runs 2
}
