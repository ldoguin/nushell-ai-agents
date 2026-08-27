# Minimal OpenTelemetry client: hand-built OTLP/HTTP-JSON envelopes sent via
# plain `http post`, no SDK/protobuf dependency -- same transport pattern as
# couchbaselabs/ais-hol's scripts/otel_client.nu (python-workshop branch),
# adapted for this harness's needs: env-var config (that reference is
# CLI-flag-only), a real `parentSpanId` on every span (that reference never
# emits one, so it has no actual parent-child nesting), and measured (not
# caller-supplied) span duration.
#
# Every span-emitting call is best-effort / fail-open -- a down or
# unreachable collector must never throw, retry, or add meaningful latency
# to a real content-generation run. That guarantee lives once, here, in
# otel-end-span; callers don't need to wrap their own calls in try/catch.

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

# record -> OTLP attributes list [{key, value: {stringValue|intValue|boolValue}}]
def to-otlp-attrs [attrs: record] {
    $attrs | columns | each {|k|
        let v = ($attrs | get $k)
        let value = (match ($v | describe) {
            "int" => { intValue: $v }
            "bool" => { boolValue: $v }
            _ => { stringValue: ($v | into string) }
        })
        { key: $k, value: $value }
    }
}

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
# and sends the OTLP span. `status_error`, if non-empty, marks the span
# ERROR (OTLP status code 2) with that message; otherwise UNSET (0).
export def otel-end-span [ctx: record, attrs: record = {}, status_error: string = ""] {
    try {
        let cfg = (otel-config)
        let end_ns = (now-ns)
        let merged_attrs = ($ctx.attrs | merge $attrs)
        let status = (if ($status_error | is-empty) {
            { code: 0 }
        } else {
            { code: 2, message: $status_error }
        })
        mut span = {
            traceId: $ctx.trace_id
            spanId: $ctx.span_id
            name: $ctx.name
            kind: 1  # SPAN_KIND_INTERNAL
            startTimeUnixNano: $"($ctx.start_ns)"
            endTimeUnixNano: $"($end_ns)"
            attributes: (to-otlp-attrs $merged_attrs)
            status: $status
        }
        # OTLP/HTTP-JSON's bytes fields reject an explicit `null` -- a root
        # span (no parent) must omit parentSpanId entirely, not set it null
        # (confirmed live against otel-desktop-viewer: emitting null here
        # gets rejected with HTTP 400 "ReadStringAsSlice" before the span is
        # ever stored).
        if ($ctx.parent_span_id != null) {
            $span = ($span | insert parentSpanId $ctx.parent_span_id)
        }
        let payload = {
            resourceSpans: [{
                resource: {
                    attributes: [{ key: "service.name", value: { stringValue: $cfg.service } }]
                }
                scopeSpans: [{
                    scope: { name: "authoring-pipeline.nu", version: "0.1.0" }
                    spans: [$span]
                }]
            }]
        }
        let headers = (["Content-Type" "application/json"] | append $cfg.headers)
        http post -H $headers $"($cfg.endpoint)/v1/traces" ($payload | to json -r)
    } catch {|e|
        # Best-effort: never throw/block the real pipeline over a down or
        # unreachable collector -- that's the common case and must stay
        # silent to the caller. But fully swallowing every failure (as the
        # reference otel_client.nu does) means a real bug in the payload
        # itself -- e.g. the null-parentSpanId 400 this module hit during
        # development -- would silently never send another span again with
        # no visible sign anything was wrong. Print instead of throw,
        # matching this repo's convention for other best-effort steps
        # (record-history-round, the SEO-polish fallback, etc).
        print $"::warning::otel-end-span \(($ctx.name)\) failed to send: ($e.msg)"
    }
}
