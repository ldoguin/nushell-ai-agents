# The OpenTelemetry sink: event -> telemetry mapping, crash recovery, replay.
use std/assert
use lib.nu *
use ../agent/agents.nu [agent]
use ../agent/loop.nu [run-agent]
use ../agent/registry.nu [get-agent]
use ../agent/journal.nu [read-journal, export-journal, recover-journals]
use ../agent/sinks/otel.nu [events-to-batch, with-closed-spans, exported-ids]
use ../agent.nu [agent-ask, agent-export]

# An event with the common fields filled in.
def ev [type: string, fields: record = {}] {
    {
        v: 1, ts: "", ts_ns: 5_000_000_000, seq: 1, type: $type
        run_id: "run1", parent_run_id: null, depth: 0, agent: "tester"
        trace_id: "t1"
    } | merge $fields
}

def tool-call [name: string, arguments: record = {}] {
    { tool_calls: [{ name: $name, arguments: $arguments }] }
}

def count-path [requests: list, path: string] {
    $requests | where path == $path | length
}

# ------------------------------------------------------- pure mapping

export def test-model-call-becomes-a-chat-span-with-metrics-and-a-log [] {
    let batch = (events-to-batch [(ev "model.end" {
        span_id: "m1", parent_span_id: "i1", start_ns: 3_000_000_000, runtime: "bedrock", model: "claude-x"
        ok: true, duration_ms: 1500, usage: { prompt_tokens: 7, completion_tokens: 3, total_tokens: 10 }
        retries: 2, finish_reason: "stop", error: "", content: { response: "{\"raw\":true}" }
    })])
    let span = ($batch.spans | first)
    assert equal ($span | select name span_id parent_span_id trace_id start_time_unix_nano end_time_unix_nano status_code) {
        name: "gen_ai.chat", span_id: "m1", parent_span_id: "i1", trace_id: "t1"
        start_time_unix_nano: 3_000_000_000, end_time_unix_nano: 5_000_000_000, status_code: 0
    }
    assert equal $span.attributes {
        "gen_ai.operation.name": "chat", "gen_ai.provider.name": "aws.bedrock", "gen_ai.request.model": "claude-x"
        "gen_ai.usage.input_tokens": 7, "gen_ai.usage.output_tokens": 3, retry_count: 2
    }
    assert equal ($batch.metrics | select name value) [
        { name: "gen_ai.client.token.usage", value: 7 }
        { name: "gen_ai.client.token.usage", value: 3 }
        { name: "gen_ai.client.operation.duration", value: 1.5 }
    ]
    assert equal ($batch.metrics | first | get attrs."gen_ai.token.type") "input"
    assert equal ($batch.logs | length) 1
    assert equal ($batch.logs.0 | select body span_id trace_id) { body: "{\"raw\":true}", span_id: "m1", trace_id: "t1" }
}

export def test-no-log-without-captured-content [] {
    let batch = (events-to-batch [(ev "model.end" { span_id: "m", start_ns: 1, runtime: "openai", model: "m", ok: true, duration_ms: 1, usage: {}, retries: 1, finish_reason: "stop", error: "" })])
    assert equal ($batch.logs | length) 0
    assert equal ($batch.spans.0.attributes."gen_ai.usage.input_tokens") 0
}

export def test-failed-model-call-is-an-error-span-without-metrics [] {
    let batch = (events-to-batch [(ev "model.end" { span_id: "m", start_ns: 1, runtime: "openai", model: "m", ok: false, duration_ms: 9, usage: {}, retries: 0, finish_reason: "", error: "provider down" })])
    let span = ($batch.spans | first)
    assert equal $span.status_code 2
    assert equal $span.status_message "provider down"
    assert equal $span.attributes."error.type" "_OTHER"
    assert equal ($span.events | first | select name attrs) { name: "exception", attrs: { "exception.type": "_OTHER", "exception.message": "provider down" } }
    assert equal ($batch.metrics | length) 0
}

export def test-tool-span-and-counter [] {
    let ok = (ev "tool.end" { span_id: "t", start_ns: 1, tool: "echo_tool", call_id: "c1", ok: true, error: "", content: { args: "{\"a\":1}", result: "out" } })
    let bad = (ev "tool.end" { span_id: "u", start_ns: 1, tool: "fail_tool", call_id: "", ok: false, error: "boom" })
    let batch = (events-to-batch [$ok $bad])
    assert equal ($batch.spans | get name) ["execute_tool echo_tool" "execute_tool fail_tool"]
    # arguments and results are opt-in: not attached by default
    assert equal $batch.spans.0.attributes { "gen_ai.operation.name": "execute_tool", "gen_ai.tool.name": "echo_tool", "gen_ai.tool.call.id": "c1" }
    assert equal $batch.spans.1.status_code 2
    assert equal $batch.spans.1.attributes."error.type" "tool_error"
    assert ("gen_ai.tool.call.id" not-in ($batch.spans.1.attributes | columns)) "an empty call id is dropped"
    assert equal ($batch.metrics | get attrs.status) ["ok" "error"]
    assert equal ($batch.metrics | get name | uniq) ["agent.tool.call.count"]

    let with = (with-env { OTEL_CAPTURE_TOOL_CONTENT: "true" } { events-to-batch [$ok] })
    assert equal $with.spans.0.attributes."gen_ai.tool.call.arguments" "{\"a\":1}"
    assert equal $with.spans.0.attributes."gen_ai.tool.call.result" "out"
}

export def test-iteration-and-run-spans [] {
    let batch = (events-to-batch [
        (ev "iteration.end" { span_id: "i", parent_span_id: "r", start_ns: 1, iteration: 2, finish_reason: "stop", error: "" })
        (ev "run.end" { span_id: "r", start_ns: 1, status: "max_turns", iterations: 9, runtime: "openai", model: "m", usage: {}, error: "" })
    ])
    assert equal ($batch.spans | get name) ["agent.iteration" "agent.run"]
    assert equal $batch.spans.0.attributes { iteration: 2, finish_reason: "stop" }
    assert equal $batch.spans.1.attributes { "gen_ai.agent.name": "tester", iterations: 9, status: "max_turns", max_iterations_reached: true }
    assert equal ($batch.metrics | first | select name value) { name: "agent.iteration.count", value: 9.0 }
    assert equal $batch.spans.1.parent_span_id null
}

export def test-start-events-are-not-exported [] {
    let batch = (events-to-batch [(ev "run.start" { span_id: "r" }) (ev "tool.start" { span_id: "t", tool: "x" }) (ev "model.start" { span_id: "m" })])
    assert equal $batch { spans: [], metrics: [], logs: [] }
}

# ---------------------------------------------------- closing orphans

export def test-open-spans-are-closed-as-failed [] {
    let events = [
        (ev "run.start" { seq: 1, ts_ns: 1000, span_id: "run", parent_span_id: null })
        (ev "iteration.start" { seq: 2, ts_ns: 1100, span_id: "it1", parent_span_id: "run", iteration: 1 })
        (ev "model.start" { seq: 3, ts_ns: 1200, span_id: "mod1", parent_span_id: "it1", runtime: "openai", model: "m" })
        (ev "model.end" { seq: 4, ts_ns: 1300, span_id: "mod1", parent_span_id: "it1", start_ns: 1200, ok: true, duration_ms: 1, usage: {}, cost: {}, finish_reason: "tool_calls", retries: 1, error: "" })
        (ev "tool.start" { seq: 5, ts_ns: 1400, span_id: "tool1", parent_span_id: "it1", tool: "slow_tool", call_id: "c" })
    ]
    let closed = (with-closed-spans $events)
    let added = ($closed | skip 5)
    assert equal ($added | get type | sort) ["iteration.end" "run.end" "tool.end"]
    assert equal ($added | get span_id | sort) ["it1" "run" "tool1"]
    assert equal ($added | get synthetic | uniq) [true]
    let tool = ($added | where type == "tool.end" | first)
    assert equal ($tool | select ok tool start_ns ts_ns) { ok: false, tool: "slow_tool", start_ns: 1400, ts_ns: 1400 }
    assert ($tool.error | str contains "the process ended during the tool call")
    let run = ($added | where type == "run.end" | first)
    assert equal ($run | select status iterations) { status: "incomplete", iterations: 1 }
    assert ($run.error | str contains "run did not finish")
    # the completed model call is untouched, and closing is idempotent
    assert equal ($closed | where type == "model.end" | length) 1
    assert equal (with-closed-spans $closed | length) ($closed | length)
    assert equal (with-closed-spans []) []
}

# ----------------------------------------------------------- live export

def run-with-otel [base: string, logs: string, responses: list, extra_env: record = {}] {
    let tools = (make-tools)
    with-env ({ AGENT_SINKS: "otel", AGENT_LOG_DIR: $logs, OTEL_SDK_DISABLED: "false", OTEL_EXPORTER_OTLP_ENDPOINT: $base } | merge $extra_env) {
        agent (mock-agent-config $responses $tools) --name live | run-agent "go"
    }
}

export def test-export-is-batched-per-iteration-and-at-run-end [] {
    let logs = ((temp-dir) | path join logs)
    let r = (fake-llm [{ status: 200, body: {} }] {|base|
        run-with-otel $base $logs [(tool-call echo_tool { text: "x" }) "done"]
    })
    assert $r.ok $r.error
    # 2 iterations + the run end = 3 flushes, one trace request each, rather than one request per span
    assert equal (count-path $r.requests "/v1/traces") 3
    assert ((count-path $r.requests "/v1/metrics") >= 1)
    assert equal (count-path $r.requests "/v1/logs") 2 "one raw reply per model call, batched per flush"
    let journal = $r.value.journal
    assert ($journal | path exists)
    # 2 model + 1 tool + 2 iteration + 1 run
    assert equal (exported-ids $journal | length) 6
    assert equal (exported-ids $journal | uniq | length) 6
}

export def test-otlp-requests-are-protobuf-with-the-right-headers [] {
    let logs = ((temp-dir) | path join logs)
    let r = (fake-llm [{ status: 200, body: {} }] {|base|
        run-with-otel $base $logs ["hi"] { OTEL_EXPORTER_OTLP_HEADERS: "x-team=obs", OTEL_SERVICE_NAME: "my-svc" }
    })
    let req = ($r.requests | where path == "/v1/traces" | first)
    assert equal $req.headers."content-type" "application/x-protobuf"
    assert equal $req.headers."x-team" "obs"
    # the resource carries the service name (visible in the raw protobuf bytes)
    assert ($req.body | into string | str contains "my-svc")
}

export def test-sdk-disabled-means-no-requests-no-journal [] {
    let logs = ((temp-dir) | path join logs)
    let r = (fake-llm [{ status: 200, body: {} }] {|base|
        run-with-otel $base $logs ["hi"] { OTEL_SDK_DISABLED: "true" }
    })
    assert equal ($r.requests | length) 0
    assert equal $r.value.journal null
    assert (not ($logs | path exists))
}

export def test-a-down-collector-never-fails-the-run-and-the-journal-keeps-everything [] {
    let logs = ((temp-dir) | path join logs)
    let r = (run-with-otel "http://127.0.0.1:1" $logs [(tool-call echo_tool { text: "x" }) "done"])
    assert equal $r.status "done"
    assert equal $r.answer "done"
    assert equal (exported-ids $r.journal) [] "nothing was marked as exported"
    assert equal (read-journal $r.journal | where type == "run.end" | length) 1
}

export def test-replaying-a-journal-exports-it-once [] {
    let logs = ((temp-dir) | path join logs)
    # run with the collector down...
    let run = (run-with-otel "http://127.0.0.1:1" $logs [(tool-call echo_tool { text: "x" }) "done"])
    # ...then replay once it is up
    let r = (fake-llm [{ status: 200, body: {} }] {|base|
        with-env { OTEL_SDK_DISABLED: "false", OTEL_EXPORTER_OTLP_ENDPOINT: $base } {
            { first: (export-journal $run.journal), second: (export-journal $run.journal) }
        }
    })
    assert $r.ok $r.error
    assert equal $r.value.first.exported_spans 6
    assert equal $r.value.first.incomplete_runs 0
    assert equal $r.value.second.exported_spans 0 "a second replay must not send anything"
    assert equal $r.value.second.already_exported 6
    assert equal (count-path $r.requests "/v1/traces") 1 "the whole journal went in one request"
}

export def test-a-failed-replay-can-be-retried [] {
    let logs = ((temp-dir) | path join logs)
    let run = (run-with-otel "http://127.0.0.1:1" $logs ["hi"])
    let down = (with-env { OTEL_SDK_DISABLED: "false", OTEL_EXPORTER_OTLP_ENDPOINT: "http://127.0.0.1:1" } { export-journal $run.journal })
    assert (not $down.ok)
    assert equal $down.exported_spans 0
    assert equal (exported-ids $run.journal) []
}

# ------------------------------------------------------------- the crash

export def test-a-killed-run-is-recoverable-from-its-journal [] {
    let repo = ($env.FILE_PWD | path dirname)
    let t = (make-tools)
    let manifest = ($t.dir | path join agents.json)
    { crashy: { runtime: "mock", model_tools: "tools.json", tool_functions: "tools.nu", responses: [(tool-call slow_tool) "never reached"] } } | to json | save $manifest
    let logs = ($t.dir | path join logs)
    let script = $"use '($repo)/agent/registry.nu' [get-agent]; use '($repo)/agent/loop.nu' [run-agent]; get-agent crashy --manifest '($manifest)' | run-agent 'go' | ignore"

    # start a run whose tool sleeps for 5 seconds, then kill -9 it mid-tool
    let pid = (with-env { AGENT_SINKS: "jsonl", AGENT_LOG_DIR: $logs } {
        ^bash -c $"nu --no-config-file -c \"($script)\" >/dev/null 2>&1 & echo $!" | str trim
    })
    mut waited = 0
    mut seen = false
    while not $seen {
        if $waited > 200 { ^kill -9 $pid; error make { msg: "the run never reached its tool call" } }
        sleep 50ms
        $waited += 1
        let files = (if ($logs | path exists) { glob $"($logs)/*.jsonl" } else { [] })
        $seen = (($files | is-not-empty) and (open --raw ($files | first) | str contains "tool.start"))
    }
    ^kill -9 $pid
    sleep 200ms

    # what the dead process left behind
    let journal = (glob $"($logs)/*.jsonl" | first)
    let events = (read-journal $journal)
    assert equal ($events | last | get type) "tool.start" "the journal ends inside the tool call"
    assert equal ($events | where type == "run.end" | length) 0
    assert equal ($events | get seq) (1..($events | length) | each { $in }) "no gaps: every emitted event reached the disk"

    # replaying it closes the open spans as failed, and exports the completed model call too
    let r = (fake-llm [{ status: 200, body: {} }] {|base|
        with-env { OTEL_SDK_DISABLED: "false", OTEL_EXPORTER_OTLP_ENDPOINT: $base } { export-journal $journal }
    })
    assert $r.ok $r.error
    assert equal $r.value.incomplete_runs 1
    # model.end (really finished) + synthetic tool.end, iteration.end, run.end
    assert equal $r.value.exported_spans 4
    assert equal (count-path $r.requests "/v1/traces") 1
}

# ------------------------------------------------------------- recovery

def make-orphan-journal [] {
    let logs = ((temp-dir) | path join logs)
    let run = (run-with-otel "http://127.0.0.1:1" $logs ["hi"])
    ^touch -d "1 hour ago" $run.journal
    $run.journal
}

export def test-recover-skips-journals-that-may-still-be-live [] {
    let logs = ((temp-dir) | path join logs)
    let run = (run-with-otel "http://127.0.0.1:1" $logs ["hi"])   # just written
    let r = (fake-llm [{ status: 200, body: {} }] {|base|
        with-env { AGENT_LOG_DIR: $logs, OTEL_SDK_DISABLED: "false", OTEL_EXPORTER_OTLP_ENDPOINT: $base } { recover-journals 10min }
    })
    assert equal $r.value []
    assert equal ($r.requests | length) 0
}

export def test-recover-exports-old-journals [] {
    let journal = (make-orphan-journal)
    let r = (fake-llm [{ status: 200, body: {} }] {|base|
        with-env { AGENT_LOG_DIR: ($journal | path dirname), OTEL_SDK_DISABLED: "false", OTEL_EXPORTER_OTLP_ENDPOINT: $base } {
            { first: (recover-journals 10min), again: (recover-journals 10min) }
        }
    })
    assert equal ($r.value.first | length) 1
    assert equal ($r.value.first.0.exported_spans) 3 "model call, iteration, run"
    assert equal $r.value.again [] "nothing left to recover the second time"
}

export def test-agent-ask-recovers-on-request [] {
    let journal = (make-orphan-journal)
    let tools = (make-tools)
    let manifest = ($tools.dir | path join agents.json)
    { a: { runtime: "mock", responses: ["ok"] } } | to json | save $manifest
    let r = (fake-llm [{ status: 200, body: {} }] {|base|
        with-env { AGENT_LOG_DIR: ($journal | path dirname), AGENT_RECOVER: "true", OTEL_SDK_DISABLED: "false", OTEL_EXPORTER_OTLP_ENDPOINT: $base } {
            agent-ask "q" --agent a --manifest $manifest
        }
    })
    assert equal $r.value "ok"
    assert equal (count-path $r.requests "/v1/traces") 1 "the old journal was replayed"
}

export def test-agent-export-takes-a-path-or-everything [] {
    let journal = (make-orphan-journal)
    let r = (fake-llm [{ status: 200, body: {} }] {|base|
        with-env { AGENT_LOG_DIR: ($journal | path dirname), OTEL_SDK_DISABLED: "false", OTEL_EXPORTER_OTLP_ENDPOINT: $base } {
            { one: (agent-export $journal), all: (agent-export) }
        }
    })
    assert equal ($r.value.one | length) 1
    assert equal ($r.value.one.0.exported_spans) 3
    assert equal ($r.value.all.0.exported_spans) 0 "already exported by the first call"
}
