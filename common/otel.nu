# Minimal OpenTelemetry client: hand-built OTLP/HTTP+protobuf requests sent
# via plain `http post`, no SDK dependency -- inspired by
# couchbaselabs/ais-hol's scripts/otel_client.nu (python-workshop branch),
# but sending real protobuf-encoded ExportTraceServiceRequest messages
# rather than that reference's OTLP/HTTP+JSON. JSON was the first version
# of this module and worked fine against otel-desktop-viewer, but a real
# spec-compliant collector (Arize Phoenix, live-tested) rejects OTLP/HTTP
# JSON outright with HTTP 415 -- protobuf is the one encoding every OTLP
# collector is required to accept. There's no protobuf library available in
# Nushell, so the wire format (varints, length-delimited fields, tags) is
# encoded by hand below -- verified byte-for-byte against a real collector's
# own stored/round-tripped span data (trace/span IDs, timestamps, and all
# three attribute types) before relying on it here.
#
# Every span-emitting call is best-effort / fail-open -- a down or
# unreachable collector must never throw, retry, or add meaningful latency
# to a real content-generation run. That guarantee lives once, here, in
# otel-end-span; callers don't need to wrap their own calls in try/catch.
# Also verified live: every span failing to send (a collector that's
# reachable but rejects the request, not just an unreachable one) still
# left the actual pipeline call it was instrumenting completely unaffected.

# Read fresh on every call (not cached) so an env change mid-process is
# picked up, same convention call_bedrock uses for AWS_REGION.
def otel-config [] {
    {
        endpoint: ($env.OTEL_EXPORTER_OTLP_ENDPOINT? | default "http://localhost:4318")
        headers: (otel-parse-headers ($env.OTEL_EXPORTER_OTLP_HEADERS? | default ""))
        service: ($env.OTEL_SERVICE_NAME? | default "authoring-pipeline")
    }
}

# "k=v,k2=v2" -> a flat list ["k" "v" "k2" "v2"] suitable for `http post`'s
# --headers flag directly (matching the [key value key value] shape
# model.nu's provider functions already use for Authorization headers).
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
# that coincidence).
export def otel-gen-id [n: int] {
    let base = (random uuid | str replace --all "-" "")
    let twice = $"($base)($base)"
    $twice | str substring 0..<$n
}

def now-ns [] {
    date now | date to-timezone GMT | into int
}

# Gates capturing tool-call arguments/results as span attributes -- opt-in
# via $env.OTEL_CAPTURE_TOOL_CONTENT ("true"/"1"/"yes"), off by default.
# OTel's own gen_ai.tool.call.arguments/gen_ai.tool.call.result attributes
# are explicitly flagged in the semantic conventions as "may contain
# sensitive information" (tool inputs/outputs can carry anything a prompt
# or a tool's data source does), so this defaults to NOT recording them
# rather than opting every deployment in silently.
export def otel-capture-tool-content [] {
    ($env.OTEL_CAPTURE_TOOL_CONTENT? | default "" | str lowercase) in ["true" "1" "yes"]
}

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

def pb-resource [service_name: string] {
    pb-attributes-fields 1 { "service.name": $service_name }
}

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
def build-export-trace-request [span: record, service_name: string] {
    let scope_spans_payload = (pb-message 1 (pb-instrumentation-scope "authoring-pipeline.nu" "0.1.0")) ++ (pb-message 2 (pb-span $span))
    let resource_spans_payload = (pb-message 1 (pb-resource $service_name)) ++ (pb-message 2 $scope_spans_payload)
    pb-message 1 $resource_spans_payload
}

# ============================================================================
# Public span API
# ============================================================================

# Starts a span as a child of `parent` ({trace_id, span_id}, or {} to start
# a new root trace). Returns a span context record `otel-end-span` needs --
# no I/O here, so this can't fail.
export def otel-start-span [name: string, parent: record = {}, attrs: record = {}] {
    let trace_id = ($parent | get -o trace_id | default (otel-gen-id 32))
    {
        trace_id: $trace_id
        span_id: (otel-gen-id 16)
        parent_span_id: ($parent | get -o span_id | default null)
        name: $name
        start_ns: (now-ns)
        attrs: $attrs
    }
}

# Computes real elapsed duration from ctx.start_ns to now, merges `attrs`
# into the span's attributes (on top of whatever otel-start-span was given),
# and sends the OTLP span as protobuf. `status_error`, if non-empty, marks
# the span ERROR (OTLP status code 2) with that message; otherwise UNSET (0).
export def otel-end-span [ctx: record, attrs: record = {}, status_error: string = ""] {
    try {
        let cfg = (otel-config)
        let end_ns = (now-ns)
        let merged_attrs = ($ctx.attrs | merge $attrs)
        let span = {
            trace_id: $ctx.trace_id
            span_id: $ctx.span_id
            parent_span_id: $ctx.parent_span_id
            name: $ctx.name
            start_time_unix_nano: $ctx.start_ns
            end_time_unix_nano: $end_ns
            attributes: $merged_attrs
            status_code: (if ($status_error | is-empty) { 0 } else { 2 })
            status_message: $status_error
        }
        let body = (build-export-trace-request $span $cfg.service)
        let headers = (["Content-Type" "application/x-protobuf"] | append $cfg.headers)
        http post -H $headers $"($cfg.endpoint)/v1/traces" $body
    } catch {|e|
        # Best-effort: never throw/block the real pipeline over a down or
        # unreachable collector -- that's the common case and must stay
        # silent to the caller. But fully swallowing every failure (as the
        # reference otel_client.nu does) means a real bug in the payload
        # itself would silently never send another span again with no
        # visible sign anything was wrong. Print instead of throw, matching
        # this repo's convention for other best-effort steps
        # (record-history-round, the SEO-polish fallback, etc).
        print $"::warning::otel-end-span \(($ctx.name)\) failed to send: ($e.msg)"
    }
}
