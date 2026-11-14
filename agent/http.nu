# The one place that talks HTTP to a model provider: timeout, retry with
# backoff, retry-after, and error reporting. Providers (agent/providers/*.nu)
# describe a call as a record and hand it to `call-provider`:
#
#   {
#     name: "Anthropic"            # label used in error messages
#     url: string
#     headers: list                # [name value name value ...]
#     body: record                 # sent as JSON
#     check: {|response| ...}      # null if the reply is usable, else
#                                  #   { error, retryable, label?, max_attempts? }
#     parse: {|response| ...}      # -> an OpenAI-shaped completion (see below)
#   }
#
# `response` is `{ status, headers, body }` as `http post --full` returns it.
# Every provider's `parse` returns the same shape, so nothing downstream knows
# which provider answered:
#
#   { choices: [{ message: { role, content, tool_calls? }, finish_reason }],
#     usage: { prompt_tokens, completion_tokens, total_tokens } }
#
# `call-provider` adds `cost` (when the endpoint is a LiteLLM proxy) and
# `retry_attempts`.

# Ceiling on how long any single model call may take before nu's http client
# aborts it. Without it a stalled connection hangs the run indefinitely,
# bounded only by the CI platform's own job timeout. 10 minutes covers long
# drafting/reasoning calls while still failing well before an hours-long hang.
const MODEL_CALL_TIMEOUT = 10min

# Attempts (including the first) before giving up on a transient error.
# Provider overload incidents have run several minutes, not seconds: 8
# attempts with the backoff below (capped at 60s/step) ride out ~5-6 minutes.
const MAX_ATTEMPTS = 8
const RETRY_MAX_DELAY = 60sec

# HTTP statuses worth retrying: rate limiting and server-side overload or
# transient failure (429, 500, 502, 503, 529 -- Anthropic's "overloaded").
# Deliberately excludes 400/401/402/403/404/413: retrying a malformed request
# or bad credentials only wastes time before failing anyway.
const RETRYABLE_STATUSES = [429 500 502 503 529]

# Base URL for a provider's API from an environment variable, so a call can go
# through a proxy such as LiteLLM. Unset or blank falls back to `default`; a
# trailing slash is dropped so callers can append a path.
export def provider-base-url [env_name: string, default: string] {
    let configured = ($env | get -o $env_name | default "" | str trim)
    if ($configured | is-empty) {
        $default
    } else {
        $configured | str trim --right --char '/'
    }
}

# Fail with a clear message instead of nu's "column not found" when a
# provider's credential is missing.
export def require-env [var: string, provider: string] {
    if ($env | get -o $var | default "" | is-empty) {
        error make { msg: $"($provider) API error: ($var) is not set" }
    }
}

# A tool call's arguments as a record: they arrive as a JSON string from
# OpenAI-shaped providers and as an object from Ollama.
export def tool-arguments [arguments: any] {
    if ($arguments | describe) == "string" {
        if ($arguments | str trim | is-empty) { {} } else { $arguments | from json }
    } else {
        $arguments
    }
}

# Anthropic and Bedrock reject two consecutive messages with the same role, but
# this repo's conversations carry one "tool" message per tool result, which
# both map to role "user". Merge adjacent same-role messages, concatenating
# their content block lists (`blocks` turns a message's content into one).
export def merge-adjacent-roles [messages: list, blocks: closure] {
    mut merged = []
    for m in $messages {
        if ($merged | is-not-empty) and (($merged | last).role == $m.role) {
            let prev = ($merged | last)
            $merged = ($merged | drop 1 | append { role: $m.role, content: ((do $blocks $prev.content) | append (do $blocks $m.content)) })
        } else {
            $merged = ($merged | append $m)
        }
    }
    $merged
}

# What a call cost, as a LiteLLM proxy reports it in response headers:
# x-litellm-response-cost (USD, input + output), plus the key's running
# x-litellm-key-spend and x-litellm-key-max-budget. All null when the endpoint
# is not a LiteLLM proxy (api.anthropic.com sends none of them). Values arrive
# as strings such as "8.3e-06".
export def proxy-cost [headers: table] {
    let lowered = ($headers | each {|h| { name: ($h.name | str lowercase), value: $h.value } })
    let num = {|name|
        let raw = ($lowered | where name == $name | get -o 0.value | default null)
        if $raw == null { null } else { try { $raw | into float } catch { null } }
    }
    {
        cost_usd: (do $num "x-litellm-response-cost")
        key_spend: (do $num "x-litellm-key-spend")
        key_max_budget: (do $num "x-litellm-key-max-budget")
    }
}

# The `check` result for a non-2xx reply: "<Name> API error (HTTP <status>
# [, detail]): <message>", retryable when the status is.
export def api-error [name: string, response: record, message: string, detail: string = ""] {
    let where = (if ($detail | is-empty) { $"HTTP ($response.status)" } else { $"HTTP ($response.status), ($detail)" })
    let text = $"($name) API error \(($where)\): ($message)"
    { retryable: ($response.status in $RETRYABLE_STATUSES), label: $text, error: $text }
}

# Parse a `retry-after` header (seconds, per RFC 9110 -- neither Anthropic nor
# OpenAI use the HTTP-date form) into a duration, or null if absent/unusable.
# Anthropic recommends honoring it over blind exponential backoff: a server
# under sustained load knows its own recovery time better than a guess does.
def retry-after-delay [headers: table] {
    let raw = ($headers | where {|h| ($h.name | str lowercase) == "retry-after" } | get -o 0.value | default "")
    if ($raw | is-empty) {
        return null
    }
    try { ($raw | into float) * 1sec } catch { null }
}

# How long to sleep before attempt `attempt + 1`: the server's retry-after when
# given (capped so a huge value can't stall a job), else exponential backoff
# from $env.AGENT_RETRY_BASE_DELAY (default 2sec), capped at 60s.
export def retry-delay [attempt: int, headers: table = []] {
    let base = ($env.AGENT_RETRY_BASE_DELAY? | default "2sec" | into duration)
    let backoff = ([($base * (2 ** ($attempt - 1))), $RETRY_MAX_DELAY] | math min)
    let server = (retry-after-delay $headers)
    if $server != null { [$server, $RETRY_MAX_DELAY] | math min } else { $backoff }
}

def retry-backoff [attempt: int, label: string, headers: table = []] {
    let delay = (retry-delay $attempt $headers)
    print --stderr $"($label) -- retrying in ($delay) \(attempt ($attempt)/($MAX_ATTEMPTS)\)"
    sleep $delay
}

# http post's own message for anything raised before a response arrives
# (dropped connection, TLS failure, DNS, but also a request the client itself
# refuses to send, e.g. a header value with a stray newline) is a generic
# "Network failure". The useful detail -- e.g. "authorization header is not a
# string" -- lives in the first label of the error's `json`. Pull it out so
# retries and the final error say the real thing.
def exception-detail [e: record] {
    let label = (try {
        ($e | get -o json | default "" | from json | get -o labels.0.text | default "")
    } catch { "" })
    if ($label | is-not-empty) and ($label != $e.msg) {
        $"($e.msg) -- ($label)"
    } else {
        $e.msg
    }
}

# Make one provider call, retrying transient failures. See the header comment
# for the shape of `spec`.
export def call-provider [spec: record] {
    mut attempt = 0
    loop {
        $attempt += 1

        let outcome = (try {
            { response: (http post --full --allow-errors --max-time $MODEL_CALL_TIMEOUT --content-type "application/json" --headers $spec.headers $spec.url $spec.body) }
        } catch {|e|
            # A stalled/refused connection, DNS failure, or --max-time abort
            # raises here rather than returning a response -- retried in case
            # it was a momentary blip (e.g. a local server still starting up).
            { exception: (exception-detail $e) }
        })

        if "exception" in $outcome {
            if $attempt >= $MAX_ATTEMPTS {
                error make { msg: $"($spec.name) API error: request failed after ($MAX_ATTEMPTS) attempts: ($outcome.exception)" }
            }
            retry-backoff $attempt $"($spec.name) request error: ($outcome.exception)"
            continue
        }

        let response = $outcome.response
        let problem = (do $spec.check $response)
        if $problem != null {
            let limit = ($problem | get -o max_attempts | default $MAX_ATTEMPTS)
            if $problem.retryable and $attempt < $limit {
                retry-backoff $attempt $problem.label $response.headers.response
                continue
            }
            error make { msg: $problem.error }
        }

        return ((do $spec.parse $response) | upsert cost (proxy-cost $response.headers.response) | upsert retry_attempts $attempt)
    }
}
