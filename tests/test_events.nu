# The event layer: what a run reports, and where it goes.
use std/assert
use lib.nu *
use ../agent/agents.nu [agent]
use ../agent/loop.nu [run-agent]
use ../agent/registry.nu [get-agent]
use ../agent/journal.nu [read-journal]

def tool-call [name: string, arguments: record = {}] {
    { tool_calls: [{ name: $name, arguments: $arguments }] }
}

# Run a mock agent with the jsonl sink on; returns { result, events, dir }.
def journaled [responses: list, extra: record = {}, env_vars: record = {}] {
    let tools = (make-tools)
    let logs = ($tools.dir | path join logs)
    let result = (with-env ({ AGENT_SINKS: "jsonl", AGENT_LOG_DIR: $logs } | merge $env_vars) {
        agent ((mock-agent-config $responses $tools) | merge $extra) --name tester | run-agent "go"
    })
    { result: $result, events: (read-journal $result.journal), dir: $tools.dir }
}

# ------------------------------------------------------------ the journal

export def test-no-sinks-means-no-files-and-no-journal [] {
    let tools = (make-tools)
    let logs = ($tools.dir | path join logs)
    let r = (with-env { AGENT_LOG_DIR: $logs } { agent (mock-agent-config ["hi"] $tools) | run-agent "go" })
    assert equal $r.journal null
    assert (not ($logs | path exists)) "a plain run must not create a log directory"
}

export def test-a-simple-run-reports-its-lifecycle [] {
    let j = (journaled ["hello"])
    assert equal ($j.events | get type) ["run.start" "iteration.start" "model.start" "model.end" "iteration.end" "run.end"]
    assert equal ($j.events | get seq) [1 2 3 4 5 6] "seq counts from 1 with no gaps"
    assert equal ($j.events | get v | uniq) [1]
    assert equal ($j.events | get run_id | uniq | length) 1
    assert equal ($j.events | get agent | uniq) ["tester"]
    assert equal ($j.events | get depth | uniq) [0]
    assert equal ($j.events | get parent_run_id | uniq) [null]
    assert (($j.events | get trace_id | uniq | length) == 1)
    assert ($j.events.0.ts =~ '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$')
    assert equal $j.result.run_id $j.events.0.run_id
}

export def test-spans-nest-run-iteration-model [] {
    let e = (journaled ["hi"]).events
    let run = ($e | where type == "run.start" | first)
    let iter = ($e | where type == "iteration.start" | first)
    let model = ($e | where type == "model.start" | first)
    assert equal $iter.parent_span_id $run.span_id
    assert equal $model.parent_span_id $iter.span_id
    # every start has a matching end with the same span id, and end events carry start_ns
    for s in ($e | where {|x| $x.type | str ends-with ".start" }) {
        let end = ($e | where {|x| ($x.type | str ends-with ".end") and $x.span_id == $s.span_id })
        assert equal ($end | length) 1 $"no single end for ($s.type)"
        assert equal ($end.0.start_ns) $s.ts_ns $"start_ns of ($s.type) should be its start time"
        assert ($end.0.ts_ns >= $end.0.start_ns)
    }
}

export def test-tool-calls-are-bracketed-by-start-and-end [] {
    let j = (journaled [(tool-call echo_tool { text: "x" }) "done"])
    let e = $j.events
    assert equal ($e | get type) [
        "run.start"
        "iteration.start" "model.start" "model.end" "tool.start" "tool.end" "iteration.end"
        "iteration.start" "model.start" "model.end" "iteration.end"
        "run.end"
    ]
    let start = ($e | where type == "tool.start" | first)
    let end = ($e | where type == "tool.end" | first)
    assert equal $start.span_id $end.span_id
    assert equal ($end | select tool call_id ok error) { tool: "echo_tool", call_id: "call_0_0", ok: true, error: "" }
    let iter = ($e | where type == "iteration.start" | first)
    assert equal $start.parent_span_id $iter.span_id "a tool call belongs to its iteration"
    # the iteration ends AFTER its tools
    assert (($e | where type == "iteration.end" | first | get seq) > $end.seq)
}

export def test-failed-tools-and-failed-model-calls-are-reported [] {
    let tool = (journaled [(tool-call fail_tool) "ok"]).events | where type == "tool.end" | first
    assert (not $tool.ok)
    assert ($tool.error | str contains "boom")

    let j = (journaled [{ error: "provider down" }])
    let e = $j.events
    assert equal ($e | get type) ["run.start" "iteration.start" "model.start" "model.end" "iteration.end" "run.end"]
    assert equal ($e | where type == "model.end" | first | select ok error) { ok: false, error: "provider down" }
    assert equal ($e | where type == "run.end" | first | get status) "error"
    assert ($e | where type == "iteration.end" | first | get error | str contains "provider down")
}

export def test-end-events-carry-usage-and-status [] {
    let e = (journaled [(tool-call echo_tool { text: "x" }) "done"]).events
    let model = ($e | where type == "model.end" | first)
    assert equal $model.usage { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
    assert equal ($model | select ok finish_reason retries runtime) { ok: true, finish_reason: "tool_calls", retries: 1, runtime: "mock" }
    let end = ($e | where type == "run.end" | last)
    assert equal ($end | select status iterations) { status: "done", iterations: 2 }
    assert equal $end.usage.total_tokens 30
}

# --------------------------------------------------------------- content

export def test-payload-text-is-under-content [] {
    let e = (journaled [(tool-call echo_tool { text: "x" }) "the answer"]).events
    assert equal ($e | where type == "run.start" | first | get content) { query: "go" }
    assert equal ($e | where type == "tool.start" | first | get content.args | from json) { text: "x" }
    assert equal ($e | where type == "tool.end" | first | get content) { result: "echo:x" }
    assert equal ($e | where type == "run.end" | first | get content) { answer: "the answer" }
    assert ($e | where type == "model.end" | last | get content.response | str contains "the answer")
}

export def test-content-can-be-turned-off [] {
    let e = (journaled [(tool-call echo_tool { text: "secret" }) "done"] {} { AGENT_LOG_CONTENT: "false" }).events
    assert (($e | where {|x| "content" in ($x | columns) } | length) == 0) "no event may carry content"
    assert (not (($e | to json) | str contains "secret"))
    assert equal ($e | length) 12 "metadata is still recorded"
}

export def test-content-is-clipped [] {
    let e = (journaled [(tool-call echo_tool { text: (1..100 | each { "x" } | str join) }) "done"] {} { AGENT_LOG_MAX_CONTENT: "30" }).events
    let result = ($e | where type == "tool.end" | first | get content.result)
    assert ($result | str contains "…[truncated, 105 characters]")
    assert (($result | str length) < 80)
}

# ------------------------------------------------------------- sub-agents

export def test-subagent-runs-share-the-journal-and-link-to-the-tool-call [] {
    let t = (make-tools)
    let manifest = ($t.dir | path join agents.json)
    {
        parent: { runtime: "mock", agents: ["helper"], responses: [{ tool_calls: [{ name: "helper", arguments: { query: "q" } }] } "done"] }
        helper: { runtime: "mock", responses: ["helped"] }
    } | to json | save $manifest
    let result = (with-env { AGENT_SINKS: "jsonl", AGENT_LOG_DIR: ($t.dir | path join logs) } {
        get-agent parent --manifest $manifest | run-agent "go"
    })
    let e = (read-journal $result.journal)
    assert equal ($e | get run_id | uniq | length) 2 "two runs in one journal"
    assert equal (ls ($t.dir | path join logs) | length) 1 "one file for the whole tree"

    let tool = ($e | where type == "tool.start" | first)
    let child_start = ($e | where type == "run.start" and depth == 1 | first)
    assert equal $child_start.parent_span_id $tool.span_id "the child run hangs under the tool call"
    assert equal $child_start.parent_run_id $result.run_id
    assert equal $child_start.trace_id $tool.trace_id "one trace"
    assert equal $child_start.agent "helper"
    assert equal ($e | where type == "tool.end" | first | get child_run_id) $child_start.run_id
    assert equal $result.subagents.0.run_id $child_start.run_id
    # each run's own seq is gapless
    for run in ($e | group-by run_id | values) {
        assert equal ($run | get seq) (1..($run | length) | each { $in }) "seq per run"
    }
}

# ---------------------------------------------------------------- safety

export def test-journal-is-private [] {
    if $nu.os-info.name == "windows" { return }
    let j = (journaled ["hi"])
    assert equal (ls --long $j.result.journal | get 0.mode) "rw-------"
}

export def test-an-unwritable-log-dir-does-not-stop-the-run [] {
    let t = (make-tools)
    let blocker = ($t.dir | path join not-a-dir)
    "a file where the log directory should be" | save $blocker
    let r = (with-env { AGENT_SINKS: "jsonl", AGENT_LOG_DIR: $blocker } {
        agent (mock-agent-config ["still works"] $t) | run-agent "go"
    })
    assert equal $r.status "done"
    assert equal $r.answer "still works"
    assert equal $r.journal null
}

export def test-unknown-sinks-are-rejected-and-the-flag-overrides-the-env [] {
    let t = (make-tools)
    let a = (agent (mock-agent-config ["hi"] $t))
    let msg = (error-of { with-env { AGENT_SINKS: "jsonl,bogus" } { $a | run-agent "go" } })
    assert ($msg | str contains "Unknown sink(s)")
    assert ($msg | str contains "bogus")
    # an explicit --sinks wins over a broken env
    let r = (with-env { AGENT_SINKS: "bogus" } { $a | run-agent "go" --sinks [] })
    assert equal $r.status "done"
}

export def test-reader-skips-a-torn-last-line [] {
    let dir = (temp-dir)
    let f = ($dir | path join j.jsonl)
    ['{"type":"run.start","v":1,"seq":1}' '{"type":"tool.start","v":1,"seq":2}' '{"type":"model.end","v":1,"se'] | str join (char nl) | save $f
    assert equal (read-journal $f | get type) ["run.start" "tool.start"]
}

# --------------------------------------------------------------- console

export def test-console-sink-shows-progress-on-stderr [] {
    let t = (make-tools)
    let repo = ($env.FILE_PWD | path dirname)
    let script = $"use '($repo)/agent/agents.nu' [agent]; use '($repo)/agent/loop.nu' [run-agent]; agent {runtime: 'mock', responses: [{tool_calls: [{name: 'echo_tool', arguments: {text: 'hi'}}]}, 'all done'], model_tools: '($t.schema)', tool_functions: '($t.functions)'} --name shown | run-agent 'go' | ignore"
    let out = (with-env { AGENT_SINKS: "console", AGENT_LOG_DIR: ($t.dir | path join logs) } { ^nu --no-config-file -c $script | complete })
    assert equal $out.exit_code 0 $out.stderr
    assert ($out.stderr | str contains "▶ shown")
    assert ($out.stderr | str contains "→ echo_tool")
    assert ($out.stderr | str contains "← echo_tool ok")
    assert ($out.stderr | str contains "◀ done, 2 iteration(s)")
    assert (not ($t.dir | path join logs | path exists)) "console alone writes no journal"
}
