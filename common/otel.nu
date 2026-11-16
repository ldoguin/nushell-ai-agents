# Minimal OpenTelemetry client: hand-built OTLP/HTTP+protobuf requests sent via
# plain `http post`, no SDK dependency. Transport only -- WHEN to emit and WHAT
# goes in a span is decided by the event layer (agent/events.nu) and the OTel
# sink that maps events to spans and metrics (agent/sinks/otel.nu).
#
# JSON-encoded OTLP is not used: a real spec-compliant collector (Arize Phoenix,
# live-tested) rejects OTLP/HTTP JSON with HTTP 415, while protobuf is the one
# encoding every collector must accept. There is no protobuf library in
# Nushell, so the wire format (varints, length-delimited fields, tags) is
# encoded by hand below -- verified byte-for-byte against a real collector's
# own stored spans (trace/span ids, timestamps, all three attribute types).
#
# `otel-export` sends a whole batch (spans, metrics, logs) in at most one
# request per signal, with a timeout, and NEVER throws: it returns
# { ok, errors } so the caller can decide what to do about a down collector
# (the sink keeps the events on disk and retries them later).
#
# Configuration is the standard OpenTelemetry environment:
#   OTEL_EXPORTER_OTLP_ENDPOINT   default http://localhost:4318
#   OTEL_EXPORTER_OTLP_HEADERS    "k=v,k2=v2"
#   OTEL_SERVICE_NAME             default nushell-agents
#   OTEL_RESOURCE_ATTRIBUTES      "k=v,k2=v2" added to every resource
#   OTEL_SDK_DISABLED             true turns every export into a no-op

# OpenTelemetry's own standard kill switch (OTEL_SDK_DISABLED=true).
export def otel-disabled [] {
    ($env.OTEL_SDK_DISABLED? | default "" | into string | str lowercase) in ["true" "1" "yes"]
}

# Read fresh on every call (not cached) so an env change mid-process is
# picked up.
def otel-config [] {
    {
        endpoint: ($env.OTEL_EXPORTER_OTLP_ENDPOINT? | default "http://localhost:4318" | str trim --right --char '/')
        headers: (otel-parse-headers ($env.OTEL_EXPORTER_OTLP_HEADERS? | default ""))
        service: ($env.OTEL_SERVICE_NAME? | default "nushell-agents")
        resource: (otel-parse-resource ($env.OTEL_RESOURCE_ATTRIBUTES? | default ""))
    }
}

# "k=v,k2=v2" -> { k: "v", k2: "v2" }
export def otel-parse-resource [raw: string] {
    if ($raw | is-empty) {
        {}
    } else {
        $raw
        | split row ","
        | where {|kv| ($kv | str trim | is-not-empty) }
        | each {|kv|
            let parts = ($kv | split row "=")
            { k: ($parts | get 0 | str trim), v: ($parts | skip 1 | str join "=" | str trim) }
        }
        | reduce --fold {} {|e, acc| $acc | upsert $e.k $e.v }
    }
}

# "k=v,k2=v2" -> a flat list ["k" "v" "k2" "v2"] suitable for `http post`'s
# --headers flag directly (matching the [key value key value] shape
# the provider modules already use for Authorization headers).
export def otel-parse-headers [raw: string] {
    if ($raw | is-empty) {
        []
    } else {
        $raw
        | split row ","
        | where {|kv| ($kv | str trim | is-not-empty) }
        | each {|kv|
            let parts = ($kv | split row "=")
            [($parts | get 0 | str trim) ($parts | skip 1 | str join "=" | str trim)]
        }
        | flatten
    }
}

# 32-hex trace id / 16-hex span id -- same technique as the reference
# client's gen_hex: strip dashes from a random UUID, double it, truncate to
# the requested length (a single UUID's 32 hex digits aren't enough for a
# 32-char trace id once dashes are removed... actually they are exactly 32,
# but doubling first keeps this correct for any n <= 32 without relying on

# ============================================================================
# Protobuf wire format -- varints, tags, length-delimited fields. Each
# "message builder" below (pb-span, pb-resource, etc.) returns the raw
# payload bytes of that message type, NOT wrapped in an outer field tag;
# the caller wraps it via `pb-message <field_num> <payload>` when embedding
# it as a field of a parent message -- this is what makes a "repeated"
# field just multiple pb-message calls concatenated, with no list wrapper
# needed (protobuf's own wire format already works that way).
# ============================================================================

def pb-varint [n: int] {
    mut v = $n
    mut out = 0x[]
    loop {
        if $v < 0x80 {
            $out = ($out ++ (($v | into binary) | bytes at 0..0))
            break
        } else {
            let byte = (($v | bits and 0x7f) | bits or 0x80)
            $out = ($out ++ (($byte | into binary) | bytes at 0..0))
            $v = ($v | bits shr 7)
        }
    }
    $out
}

def pb-tag [field_num: int, wire_type: int] {
    pb-varint (($field_num | bits shl 3) | bits or $wire_type)
}

def pb-len-delim [field_num: int, payload: binary] {
    (pb-tag $field_num 2) ++ (pb-varint ($payload | bytes length)) ++ $payload
}

def pb-string [field_num: int, s: string] {
    pb-len-delim $field_num ($s | into binary)
}

def pb-bytes [field_num: int, b: binary] {
    pb-len-delim $field_num $b
}

def pb-varint-field [field_num: int, value: int] {
    (pb-tag $field_num 0) ++ (pb-varint $value)
}

def pb-bool-field [field_num: int, value: bool] {
    (pb-tag $field_num 0) ++ (pb-varint (if $value { 1 } else { 0 }))
}

def pb-fixed64-field [field_num: int, value: int] {
    # nu's `int | into binary` already produces an 8-byte little-endian
    # encoding, which is exactly protobuf's fixed64 wire format -- no
    # manual byte-swapping needed (verified against a real collector's
    # decoded timestamps).
    (pb-tag $field_num 1) ++ ($value | into binary)
}

def pb-message [field_num: int, payload: binary] {
    pb-len-delim $field_num $payload
}

def pb-concat [items: list<binary>] {
    $items | reduce --fold 0x[] {|it, acc| $acc ++ $it }
}

# --- OTLP-specific message builders ---

# AnyValue oneof -- only the 3 variants this module's span attributes ever
# use (string_value=1, bool_value=2, int_value=3); OTLP's other variants
# (double/array/kvlist/bytes) aren't needed here.
def pb-any-value-payload [v: any] {
    match ($v | describe) {
        "int" => (pb-varint-field 3 $v)
        "bool" => (pb-bool-field 2 $v)
        _ => (pb-string 1 ($v | into string))
    }
}

def pb-key-value [key: string, value: any] {
    (pb-string 1 $key) ++ (pb-message 2 (pb-any-value-payload $value))
}

# Encodes a whole `attrs` record as repeated KeyValue fields at `field_num`
# -- used for Span.attributes (field 9) and Resource.attributes (field 1).
def pb-attributes-fields [field_num: int, attrs: record] {
    pb-concat ($attrs | columns | each {|k| pb-message $field_num (pb-key-value $k ($attrs | get $k)) })
}

def pb-instrumentation-scope [name: string, version: string] {
    (pb-string 1 $name) ++ (pb-string 2 $version)
}

# Span.Event: time_unix_nano=1 (fixed64), name=2 (string), attributes=3
# (repeated KeyValue) -- field numbers verified directly against
# opentelemetry-proto's trace.proto, same discipline as every other
# pb-* builder in this file.
def pb-event [ev: record] {
    (pb-fixed64-field 1 $ev.time_ns) ++ (pb-string 2 $ev.name) ++ (pb-attributes-fields 3 ($ev.attrs | default {}))
}

# CI/CD + VCS resource attributes, read directly from the standard env
# vars GitHub Actions itself sets on every job -- verified against
# OTel's actual CI/CD semantic conventions doc (cicd.pipeline.*,
# vcs.repository.name, vcs.ref.head.name), not guessed. Empty/absent
# outside GitHub Actions, so this stays a no-op for local runs -- genuinely
# generic (any consumer of this submodule gets it for free), not coupled
# to this specific pipeline repo's own conventions.
def pb-status [code: int, message: string] {
    mut payload = 0x[]
    if ($message | is-not-empty) { $payload = $payload ++ (pb-string 2 $message) }
    if $code != 0 { $payload = $payload ++ (pb-varint-field 3 $code) }
    $payload
}

# ctx/ended-span record -> Span message payload. parent_span_id must be
# omitted entirely for a root span, not encoded as empty bytes -- OTLP
# leaves the field unset to mean "no parent", same rule that broke the
# JSON version of this module when it sent parentSpanId:null instead.
def pb-span [span: record] {
    mut payload = 0x[]
    $payload = $payload ++ (pb-bytes 1 ($span.trace_id | decode hex))
    $payload = $payload ++ (pb-bytes 2 ($span.span_id | decode hex))
    if ($span.parent_span_id? | default null) != null {
        $payload = $payload ++ (pb-bytes 4 ($span.parent_span_id | decode hex))
    }
    $payload = $payload ++ (pb-string 5 $span.name)
    $payload = $payload ++ (pb-varint-field 6 1)  # SPAN_KIND_INTERNAL
    $payload = $payload ++ (pb-fixed64-field 7 $span.start_time_unix_nano)
    $payload = $payload ++ (pb-fixed64-field 8 $span.end_time_unix_nano)
    $payload = $payload ++ (pb-attributes-fields 9 ($span.attributes | default {}))
    $payload = $payload ++ (pb-concat (($span.events? | default []) | each {|ev| pb-message 11 (pb-event $ev) }))
    let status_code = ($span.status_code? | default 0)
    let status_message = ($span.status_message? | default "")
    if $status_code != 0 or ($status_message | is-not-empty) {
        $payload = $payload ++ (pb-message 15 (pb-status $status_code $status_message))
    }
    $payload
}

# Full ExportTraceServiceRequest for one span -- one resourceSpans, one
# scopeSpans, one span, matching this module's one-span-per-HTTP-call
# design (same as the JSON version it replaces).


# double is wire-type 1 (64-bit) like fixed64, but the VALUE bits are an
# IEEE-754 double, not a plain integer -- `value | into float | into
# binary` produces exactly that (verified: 1.0 -> 00 00 00 00 00 00 f0 3f,
# the textbook IEEE-754 encoding), whereas reusing pb-fixed64-field's
# plain-integer encoding here would silently produce garbage bits for the
# same numeric value.
def pb-double-field [field_num: int, value: float] {
    (pb-tag $field_num 1) ++ ($value | into binary)
}

# One HistogramDataPoint representing a single observation (count=1, sum
# = that one value) -- this module sends one data point per emitted
# metric rather than aggregating locally over an export interval (the
# same one-record-per-HTTP-call design the trace side uses), so
# bucket_counts/explicit_bounds are omitted entirely rather than faked;
# per the proto's own comment, a histogram with zero bucket_counts and
# zero explicit_bounds is valid, it just carries no distribution/
# percentile info of its own -- the collector accumulates count/sum
# across many such points to build that up over time.
def pb-histogram-data-point [value: float, attrs: record, time_ns: int] {
    mut payload = 0x[]
    $payload = $payload ++ (pb-fixed64-field 3 $time_ns)  # time_unix_nano
    $payload = $payload ++ (pb-fixed64-field 4 1)          # count (fixed64, not varint)
    $payload = $payload ++ (pb-double-field 5 $value)      # sum
    $payload = $payload ++ (pb-attributes-fields 9 $attrs)
    $payload
}

def pb-histogram-metric [name: string, unit: string, data_point_payload: binary] {
    # aggregation_temporality = DELTA(1): each emitted point is one
    # independent observation, not a running total this process
    # maintains -- DELTA is the correct declaration for that, letting the
    # collector's own pipeline accumulate points into cumulative series.
    let histogram_payload = (pb-message 1 $data_point_payload) ++ (pb-varint-field 2 1)
    (pb-string 1 $name) ++ (pb-string 3 $unit) ++ (pb-message 9 $histogram_payload)
}

# NumberDataPoint (metrics.proto): start_time_unix_nano=2, time_unix_nano=3,
# the value oneof's as_double=4, attributes=7 -- verified directly against
# the proto source, same as every other field number in this file.
def pb-number-data-point [value: float, attrs: record, time_ns: int] {
    mut payload = 0x[]
    $payload = $payload ++ (pb-fixed64-field 3 $time_ns)
    $payload = $payload ++ (pb-double-field 4 $value)
    $payload = $payload ++ (pb-attributes-fields 7 $attrs)
    $payload
}

# Sum message: data_points=1, aggregation_temporality=2, is_monotonic=3.
# is_monotonic=true here since every counter this module emits (tool
# calls, agent iterations) only ever increases -- same DELTA-per-call
# design as the histogram side: one data point per observation, letting
# the collector accumulate the running total.
def pb-sum-metric [name: string, unit: string, data_point_payload: binary] {
    let sum_payload = (pb-message 1 $data_point_payload) ++ (pb-varint-field 2 1) ++ (pb-bool-field 3 true)
    (pb-string 1 $name) ++ (pb-string 3 $unit) ++ (pb-message 7 $sum_payload)
}

# LogRecord (logs.proto): time_unix_nano=1, severity_number=2, severity_text=3,
# body=5 (AnyValue), attributes=6, trace_id=9 (bytes), span_id=10 (bytes) --
# field numbers verified directly against the proto source, same discipline
# as every other message in this file. trace_id/span_id are only written
# when a real span_ctx was given -- an absent/invalid trace_id or span_id
# is how the spec says "not associated with a trace/span", same rule that
# governs a root span's absent parent_span_id elsewhere in this module.
def pb-log-record [rec: record] {
    mut payload = 0x[]
    $payload = $payload ++ (pb-fixed64-field 1 $rec.time_ns)
    $payload = $payload ++ (pb-varint-field 2 $rec.severity_number)
    $payload = $payload ++ (pb-string 3 $rec.severity_text)
    $payload = $payload ++ (pb-message 5 (pb-any-value-payload $rec.body))
    $payload = $payload ++ (pb-attributes-fields 6 ($rec.attrs | default {}))
    if ($rec.trace_id? | default null) != null {
        $payload = $payload ++ (pb-bytes 9 ($rec.trace_id | decode hex))
    }
    if ($rec.span_id? | default null) != null {
        $payload = $payload ++ (pb-bytes 10 ($rec.span_id | decode hex))
    }
    $payload
}

# "debug"/"info"/"warn"/"error"/"fatal" -> OTel's SeverityNumber, per the
# Log Data Model spec's own enum (INFO=9, WARN=13, ERROR=17, DEBUG=5,
# FATAL=21) -- an unrecognized value defaults to INFO rather than erroring,
# since severity here is advisory (filtering/color in a UI), not something
# that should ever block a send.
def otel-severity-number [severity: string] {
    match ($severity | str lowercase) {
        "debug" => 5
        "warn" => 13
        "warning" => 13
        "error" => 17
        "fatal" => 21
        _ => 9
    }
}

# Resource = who is sending: the service name plus OTEL_RESOURCE_ATTRIBUTES.
def pb-resource [service_name: string, extra: record] {
    pb-attributes-fields 1 ({ "service.name": $service_name } | merge $extra)
}

# One ExportTraceServiceRequest holding all `spans` (OTLP's own repeated
# field: just more pb-message calls concatenated).
def build-export-trace-request [spans: list, cfg: record] {
    let scope = (pb-message 1 (pb-instrumentation-scope "nushell-agents" "0.2.0")) ++ (pb-concat ($spans | each {|s| pb-message 2 (pb-span $s) }))
    pb-message 1 ((pb-message 1 (pb-resource $cfg.service $cfg.resource)) ++ (pb-message 2 $scope))
}

# One ExportMetricsServiceRequest: `metrics` are
# { kind: "histogram" | "sum", name, unit, value, attrs, time_ns }.
def build-export-metrics-request [metrics: list, cfg: record] {
    let payloads = ($metrics | each {|m|
        let metric = (if $m.kind == "histogram" {
            pb-histogram-metric $m.name $m.unit (pb-histogram-data-point ($m.value | into float) $m.attrs $m.time_ns)
        } else {
            pb-sum-metric $m.name $m.unit (pb-number-data-point ($m.value | into float) $m.attrs $m.time_ns)
        })
        pb-message 2 $metric
    })
    let scope = (pb-message 1 (pb-instrumentation-scope "nushell-agents" "0.2.0")) ++ (pb-concat $payloads)
    pb-message 1 ((pb-message 1 (pb-resource $cfg.service $cfg.resource)) ++ (pb-message 2 $scope))
}

# One ExportLogsServiceRequest: `logs` are
# { body, attrs, severity, time_ns, trace_id, span_id }.
def build-export-logs-request [logs: list, cfg: record] {
    let records = ($logs | each {|l|
        pb-message 2 (pb-log-record {
            time_ns: $l.time_ns
            severity_number: (otel-severity-number ($l.severity? | default "info"))
            severity_text: (($l.severity? | default "info") | str uppercase)
            body: $l.body
            attrs: ($l.attrs? | default {})
            trace_id: ($l.trace_id? | default null)
            span_id: ($l.span_id? | default null)
        })
    })
    let scope = (pb-message 1 (pb-instrumentation-scope "nushell-agents" "0.2.0")) ++ (pb-concat $records)
    pb-message 1 ((pb-message 1 (pb-resource $cfg.service $cfg.resource)) ++ (pb-message 2 $scope))
}

# ============================================================================
# Public API
# ============================================================================

# Send a batch: { spans: [span], metrics: [metric], logs: [log] } (each
# optional; see the build-export-* functions for the shapes, and pb-span for a
# span's fields: trace_id, span_id, parent_span_id, name, start_time_unix_nano,
# end_time_unix_nano, attributes, events, status_code, status_message).
# One request per non-empty signal, each with a timeout so an unreachable
# collector cannot stall a run. Never throws. Returns { ok, errors, sent }.
export def otel-export [batch: record] {
    if (otel-disabled) {
        return { ok: true, errors: [], sent: [] }
    }
    let cfg = (otel-config)
    let headers = (["Content-Type" "application/x-protobuf"] | append $cfg.headers)
    let spans = ($batch | get -o spans | default [])
    let metrics = ($batch | get -o metrics | default [])
    let logs = ($batch | get -o logs | default [])

    let outcomes = ([
        { name: "traces", path: "/v1/traces", items: $spans, build: {|items| build-export-trace-request $items $cfg } }
        { name: "metrics", path: "/v1/metrics", items: $metrics, build: {|items| build-export-metrics-request $items $cfg } }
        { name: "logs", path: "/v1/logs", items: $logs, build: {|items| build-export-logs-request $items $cfg } }
    ] | where {|signal| $signal.items | is-not-empty } | each {|signal|
        try {
            let body = (do $signal.build $signal.items)
            http post --max-time 15sec -H $headers $"($cfg.endpoint)($signal.path)" $body | ignore
            { name: $signal.name, error: "" }
        } catch {|e|
            { name: $signal.name, error: $"($signal.name): ($e.msg)" }
        }
    })
    let errors = ($outcomes | where error != "" | get error)
    let sent = ($outcomes | where error == "" | get name)
    { ok: ($errors | is-empty), errors: $errors, sent: $sent }
}
