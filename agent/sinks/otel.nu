# Maps events (agent/events.nu) to OpenTelemetry spans, metrics and logs and
# exports them. The mapping is pure -- `events-to-batch` takes events and
# returns what to send -- so it is testable without a collector and replayable
# from a journal.
#
# One span per finished unit, built from its END event alone (end events repeat
# start_ns), named per the GenAI semantic conventions where they define one:
#   run.end        agent.run
#   iteration.end  agent.iteration
#   model.end      gen_ai.chat          (+ token-usage and duration histograms,
#                                        + the raw reply as a correlated log)
#   tool.end       execute_tool <name>  (+ a call counter)
# Tool arguments and results are attached only when
# $env.OTEL_CAPTURE_TOOL_CONTENT is on -- the spec flags both as possibly
# sensitive -- and only if the journal captured them.
use ../../common/otel.nu [otel-export, otel-disabled]

const EXPORTABLE = ["run.end" "iteration.end" "model.end" "tool.end"]

# OTel's gen_ai.provider.name well-known values; runtimes with none (ollama,
# mock) pass through as custom values, which the spec allows.
def provider-name [runtime: string] {
    match $runtime {
        "bedrock" => "aws.bedrock"
        _ => $runtime
    }
}

def capture-tool-content [] {
    ($env.OTEL_CAPTURE_TOOL_CONTENT? | default "" | str lowercase) in ["true" "1" "yes"]
}

# A record without its null fields (the encoder would send them as "").
def compact-attrs [attrs: record] {
    $attrs | items {|k, v| { k: $k, v: $v } } | where {|e| $e.v != null } | reduce --fold {} {|e, acc| $acc | insert $e.k $e.v }
}

def span-of [e: record, name: string, attrs: record] {
    let error = ($e | get -o error | default "")
    {
        trace_id: $e.trace_id
        span_id: $e.span_id
        parent_span_id: ($e | get -o parent_span_id | default null)
        name: $name
        start_time_unix_nano: $e.start_ns
        end_time_unix_nano: $e.ts_ns
        attributes: (compact-attrs $attrs)
        events: (if ($error | is-empty) { [] } else { [{ name: "exception", time_ns: $e.ts_ns, attrs: { "exception.type": "_OTHER", "exception.message": $error } }] })
        status_code: (if ($error | is-empty) { 0 } else { 2 })
        status_message: $error
    }
}

# Events -> { spans, metrics, logs } for `otel-export`. Events that are not end
# events are ignored.
export def events-to-batch [events: list] {
    mut spans = []
    mut metrics = []
    mut logs = []
    for e in $events {
        match $e.type {
            "model.end" => {
                let attrs = {
                    "gen_ai.operation.name": "chat"
                    "gen_ai.provider.name": (provider-name ($e.runtime? | default "unknown"))
                    "gen_ai.request.model": ($e.model? | default "unknown")
                }
                let error = ($e | get -o error | default "")
                $spans = ($spans | append (span-of $e "gen_ai.chat" ($attrs | merge {
                    "gen_ai.usage.input_tokens": ($e.usage?.prompt_tokens? | default 0)
                    "gen_ai.usage.output_tokens": ($e.usage?.completion_tokens? | default 0)
                    retry_count: ($e.retries? | default 1)
                    "error.type": (if ($error | is-empty) { null } else { "_OTHER" })
                })))
                if $e.ok {
                    $metrics = ($metrics | append [
                        { kind: "histogram", name: "gen_ai.client.token.usage", unit: "{token}", value: ($e.usage?.prompt_tokens? | default 0), attrs: ($attrs | insert "gen_ai.token.type" "input"), time_ns: $e.ts_ns }
                        { kind: "histogram", name: "gen_ai.client.token.usage", unit: "{token}", value: ($e.usage?.completion_tokens? | default 0), attrs: ($attrs | insert "gen_ai.token.type" "output"), time_ns: $e.ts_ns }
                        { kind: "histogram", name: "gen_ai.client.operation.duration", unit: "s", value: (($e.duration_ms? | default 0) / 1000.0), attrs: $attrs, time_ns: $e.ts_ns }
                    ])
                    # The raw reply, correlated to the span it belongs to.
                    let raw = ($e.content?.response? | default null)
                    if $raw != null {
                        $logs = ($logs | append { body: $raw, attrs: $attrs, severity: "info", time_ns: $e.ts_ns, trace_id: $e.trace_id, span_id: $e.span_id })
                    }
                }
            }
            "tool.end" => {
                let name = $e.tool
                let content = (if (capture-tool-content) { $e.content? | default {} } else { {} })
                $spans = ($spans | append (span-of $e $"execute_tool ($name)" {
                    "gen_ai.operation.name": "execute_tool"
                    "gen_ai.tool.name": $name
                    "gen_ai.tool.call.id": (if ($e.call_id? | default "" | is-empty) { null } else { $e.call_id })
                    "gen_ai.tool.call.arguments": ($content.args? | default null)
                    "gen_ai.tool.call.result": ($content.result? | default null)
                    "error.type": (if $e.ok { null } else { "tool_error" })
                }))
                $metrics = ($metrics | append { kind: "sum", name: "agent.tool.call.count", unit: "{call}", value: 1.0, attrs: { "gen_ai.tool.name": $name, status: (if $e.ok { "ok" } else { "error" }) }, time_ns: $e.ts_ns })
            }
            "iteration.end" => {
                $spans = ($spans | append (span-of $e "agent.iteration" {
                    iteration: $e.iteration
                    finish_reason: (if ($e.finish_reason? | default "" | is-empty) { null } else { $e.finish_reason })
                }))
            }
            "run.end" => {
                $spans = ($spans | append (span-of $e "agent.run" {
                    "gen_ai.agent.name": $e.agent
                    iterations: $e.iterations
                    status: $e.status
                    max_iterations_reached: ($e.status == "max_turns")
                }))
                $metrics = ($metrics | append { kind: "sum", name: "agent.iteration.count", unit: "{iteration}", value: ($e.iterations | into float), attrs: { "gen_ai.provider.name": (provider-name ($e.runtime? | default "unknown")), "gen_ai.request.model": ($e.model? | default "unknown") }, time_ns: $e.ts_ns })
            }
            _ => {}
        }
    }
    { spans: $spans, metrics: $metrics, logs: $logs }
}

# A journal from a process that died holds start events with no matching end.
# Close each such span with a synthetic end event at the time of the last event
# seen, marked as failed, so the exported trace shows where the run stopped
# rather than a gap. Pure; events that already have ends are untouched.
export def with-closed-spans [events: list] {
    if ($events | is-empty) { return $events }
    let ended = ($events | where {|e| $e.type | str ends-with ".end" } | get span_id)
    let last_ns = ($events | get ts_ns | math max)
    let open = ($events | where {|e| ($e.type | str ends-with ".start") and ($e.span_id not-in $ended) })
    let closing = ($open | reverse | each {|s|
        let base = {
            v: 1, ts: "", ts_ns: $last_ns, synthetic: true
            run_id: $s.run_id, parent_run_id: $s.parent_run_id, depth: $s.depth, agent: $s.agent, trace_id: $s.trace_id
            span_id: $s.span_id, parent_span_id: ($s.parent_span_id? | default null), start_ns: $s.ts_ns
            runtime: ($s.runtime? | default null), model: ($s.model? | default null)
        }
        match $s.type {
            "run.start" => ($base | merge { type: "run.end", seq: -1, status: "incomplete", iterations: ($events | where {|e| $e.type == "iteration.start" and $e.run_id == $s.run_id } | length), usage: {}, error: "run did not finish: the process ended mid-run" })
            "iteration.start" => ($base | merge { type: "iteration.end", seq: -1, iteration: $s.iteration, finish_reason: "", error: "the process ended during this iteration" })
            "model.start" => ($base | merge { type: "model.end", seq: -1, ok: false, duration_ms: (($last_ns - $s.ts_ns) / 1_000_000 | into int), usage: {}, cost: {}, finish_reason: "", retries: 0, error: "the process ended during the model call" })
            "tool.start" => ($base | merge { type: "tool.end", seq: -1, tool: $s.tool, call_id: ($s.call_id? | default ""), ok: false, duration_ms: (($last_ns - $s.ts_ns) / 1_000_000 | into int), error: "the process ended during the tool call" })
            _ => null
        }
    } | compact)
    $events | append $closing
}

def marker-file [journal: string] {
    $"($journal).exported"
}

# Span ids already exported from this journal (one per line in <journal>.exported).
export def exported-ids [journal: any] {
    if $journal == null or not (marker-file $journal | path exists) {
        []
    } else {
        open --raw (marker-file $journal) | lines | where {|l| $l | is-not-empty }
    }
}

# Map and send `events`, skipping spans this journal has already exported, and
# record the ones that went through so a replay never sends them twice.
# Returns { ok, errors, exported: [span ids] }; never throws.
export def export-events [events: list, journal: any] {
    if (otel-disabled) {
        return { ok: true, errors: [], exported: [] }
    }
    let done = (exported-ids $journal)
    let todo = ($events | where {|e| ($e.type in $EXPORTABLE) and ($e.span_id not-in $done) })
    if ($todo | is-empty) {
        return { ok: true, errors: [], exported: [] }
    }
    let result = (otel-export (events-to-batch $todo))
    if not $result.ok {
        return ($result | select ok errors | insert exported [])
    }
    let ids = ($todo | get span_id)
    if $journal != null {
        try { $"($ids | str join (char nl))\n" | save --append (marker-file $journal) } catch {|e|
            return { ok: false, errors: [$"cannot record exported spans: ($e.msg)"], exported: $ids }
        }
    }
    { ok: true, errors: [], exported: $ids }
}
