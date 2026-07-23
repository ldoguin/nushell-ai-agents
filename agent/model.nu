use ../common/utils.nu *

# Ceiling on how long any single model completion call is allowed to take
# before nu's http client aborts it. Without this, a stalled TCP
# connection (e.g. a dropped connection with no server-side response)
# hangs the calling job indefinitely, bounded only by the CI platform's
# own job timeout (GitHub Actions' default is 6 hours) rather than
# anything under this codebase's control. 10 minutes comfortably covers
# normal completion latency -- including long multi-thousand-word
# drafting/reasoning calls -- while still failing fast enough for a
# retry loop or a human to notice well before an hours-long hang.
const MODEL_CALL_TIMEOUT = 10min

# Attempts (including the first) for a model call before giving up on a
# transient error. Anthropic's own overload incidents have run several
# minutes, not seconds -- 8 attempts with the backoff below (capped at
# 60s/step) spans up to ~5-6min of total retry sleep, long enough to ride
# out a real overload window, while callers running inside a
# multi-hour-budgeted CI job (see product-narrative-agent.yml's
# timeout-minutes) can easily absorb that on top of MODEL_CALL_TIMEOUT.
const MAX_ATTEMPTS = 8
const RETRY_BASE_DELAY = 2sec
const RETRY_MAX_DELAY = 60sec

# HTTP status codes worth retrying: rate limiting and server-side
# overload/transient failures, per Anthropic's and OpenAI's own error
# docs (429 rate_limit_error, 500 api_error, 502/503 upstream/gateway,
# 529 overloaded_error -- the exact error a stuck product-narrative-agent
# run hit in practice). Deliberately excludes 400/401/402/403/404/413 --
# retrying a malformed request or bad credentials just wastes time before
# failing anyway, with no chance of succeeding.
const RETRYABLE_STATUSES = [429 500 502 503 529]

# Parse a `retry-after` response header (seconds, per RFC 9110 -- neither
# Anthropic nor OpenAI use the HTTP-date variant) into a duration, if
# present and numeric. Anthropic explicitly recommends honoring this
# header over blind exponential backoff when it's given -- a server under
# real sustained load knows its own recovery time better than a client's
# guess does.
def retry-after-delay [headers: table] {
    let raw = ($headers | where {|h| ($h.name | str lowercase) == "retry-after" } | get -o 0.value | default "")
    if ($raw | is-empty) {
        return null
    }
    try {
        ($raw | into int) * 1sec
    } catch {
        null
    }
}

# Sleep before the next of MAX_ATTEMPTS attempts, logging why. Uses the
# server's `retry-after` header when present (capped at RETRY_MAX_DELAY
# so a misbehaving/huge value can't stall a job for an unreasonable
# time), otherwise falls back to exponential backoff. `label` identifies
# which runtime/error triggered it, since all three model_call closures
# share this helper; `headers` is the response headers table to check
# for `retry-after` -- omit (empty table) for network-level exceptions,
# which have no response to read a header from.
def retry-backoff [attempt: int, label: string, headers: table = []] {
    let server_delay = (retry-after-delay $headers)
    let backoff_delay = ([($RETRY_BASE_DELAY * (2 ** ($attempt - 1))), $RETRY_MAX_DELAY] | math min)
    let delay = if $server_delay != null { ([$server_delay, $RETRY_MAX_DELAY] | math min) } else { $backoff_delay }
    print $"($label) -- retrying in ($delay) \(attempt ($attempt)/($MAX_ATTEMPTS)\)"
    sleep $delay
}

# Call local ollama API
export def callama [$model, $messages, $stream, $endpoint, $model_tools, options] {
    let url = $"http://localhost:11434/($endpoint)" 
    let json = {
        model: $model,
        messages: $messages,
        tools: $model_tools,
        stream: $stream,
        options: {
            temperature : 0
        }
        
    };
    let json = $json | merge $options
    $url | log
    $json | log
    let jsonString = ( $json | to json )

    mut attempt = 0
    loop {
        $attempt = $attempt + 1

        let outcome = (try {
            { kind: "response", response: (http post --max-time $MODEL_CALL_TIMEOUT $url  $json) }
        } catch {|e|
            # Most common case locally: ollama still loading the model
            # into memory refuses connections briefly right after
            # startup -- worth a couple of retries rather than failing
            # the whole run over a few seconds of startup lag.
            { kind: "exception", error: $e }
        })

        if $outcome.kind == "exception" {
            if $attempt >= $MAX_ATTEMPTS {
                error make { msg: $"Ollama request error: request failed after ($MAX_ATTEMPTS) attempts: ($outcome.error.msg)" }
            }
            retry-backoff $attempt $"Ollama request error: ($outcome.error.msg)"
            continue
        }

        return $outcome.response
    }
}

# Call openai api
export def calloai [model, messages, model_tools, options] {
    let url = "https://api.openai.com/v1/chat/completions" 
    let json = {
        model: $model,
        messages: $messages,
        tools: $model_tools
    };
    let json = $json | merge $options
    let jsonString = ( $json | to json )

    mut attempt = 0
    loop {
        $attempt = $attempt + 1

        let outcome = (try {
            let response = ( http post  -e -f --max-time $MODEL_CALL_TIMEOUT $url $json --headers ["Authorization" $"Bearer ($env.OPENAI_API_KEY) " ]   --content-type "application/json")
            { kind: "response", response: $response }
        } catch {|e|
            { kind: "exception", error: $e }
        })

        if $outcome.kind == "exception" {
            if $attempt >= $MAX_ATTEMPTS {
                error make { msg: $"OpenAI API error: request failed after ($MAX_ATTEMPTS) attempts: ($outcome.error.msg)" }
            }
            retry-backoff $attempt $"OpenAI request error: ($outcome.error.msg)"
            continue
        }

        let response = $outcome.response
        # OpenAI's error body shape is { error: { message, type, code } }
        # with no top-level "type": "error" marker (unlike Anthropic's),
        # so use the HTTP status itself to detect a non-2xx response.
        if ($response.status in $RETRYABLE_STATUSES) and ($attempt < $MAX_ATTEMPTS) {
            let msg = ($response.body | get -o error.message | default "unknown error")
            retry-backoff $attempt $"OpenAI API error \(HTTP ($response.status)\): ($msg)" $response.headers.response
            continue
        }

        return $response.body
    }
}

# Translate an OpenAI-style tools.json entry list
# ([{type:"function", function:{name,description,parameters}}], the only
# shape agents.json's model_tools/tool_functions convention uses) into
# Anthropic's `tools` request shape ([{name,description,input_schema}]).
def openai_tools_to_anthropic [model_tools: list] {
    $model_tools | each {|t|
        {
            name: $t.function.name
            description: ($t.function | get -o description | default "")
            input_schema: $t.function.parameters
        }
    }
}

# Translate this repo's OpenAI-shaped message list (the only shape
# agent/internal.nu's `call`/`execute` ever build, regardless of runtime)
# into Anthropic's { system, messages } request shape:
#   - system-role message(s) become the top-level `system` field
#   - "tool"-role messages (the tool-result turns `call` appends after a
#     tool_calls response) become user-role tool_result blocks
#   - assistant messages carrying `tool_calls` (reconstructed by
#     anthropic_response_to_openai below) get their tool_use blocks
#     rebuilt from those same tool_calls entries, so a multi-round tool
#     conversation round-trips correctly
#   - adjacent entries that map to the same Anthropic role are merged
#     into one message, since Anthropic rejects two consecutive messages
#     sharing a role -- `call` appends one "tool"-role message per tool
#     call rather than grouping parallel calls into a single turn.
def openai_messages_to_anthropic [messages: list] {
    let system = ($messages | where role == "system" | get content | str join "\n\n")
    let converted = ($messages | where role != "system" | each {|m|
        match $m.role {
            "tool" => {
                role: "user"
                content: [{
                    type: "tool_result"
                    tool_use_id: ($m | get -o tool_call_id | default ($m | get -o id | default ""))
                    content: ($m | get -o content | default "")
                }]
            }
            "assistant" => (
                if ($m | get -o tool_calls | default [] | is-not-empty) {
                    let text_blocks = (if ($m | get -o content | default "" | is-empty) { [] } else { [{ type: "text", text: $m.content }] })
                    let tool_blocks = ($m.tool_calls | each {|tc| { type: "tool_use", id: $tc.id, name: $tc.function.name, input: ($tc.function.arguments | from json) } })
                    { role: "assistant", content: ($text_blocks | append $tool_blocks) }
                } else {
                    { role: "assistant", content: ($m | get -o content | default "") }
                }
            )
            _ => { role: "user", content: ($m | get -o content | default "") }
        }
    })

    mut merged = []
    for m in $converted {
        if ($merged | is-not-empty) and (($merged | last).role == $m.role) {
            let prev = ($merged | last)
            let prev_content = (if ($prev.content | describe) == "string" { [{ type: "text", text: $prev.content }] } else { $prev.content })
            let cur_content = (if ($m.content | describe) == "string" { [{ type: "text", text: $m.content }] } else { $m.content })
            $merged = ($merged | drop 1 | append { role: $m.role, content: ($prev_content | append $cur_content) })
        } else {
            $merged = ($merged | append $m)
        }
    }
    { system: $system, messages: $merged }
}

# Translate Anthropic's { content: [...blocks], stop_reason } response
# shape back into an OpenAI-shaped { choices: [{ message, finish_reason }] }
# response -- the only shape agent/internal.nu's `execute`/`call` know how
# to read, so every downstream consumer (including run_agent's ReAct-style
# parsing) stays runtime-agnostic.
def anthropic_response_to_openai [response: record] {
    let blocks = ($response | get -o content | default [])
    let text = ($blocks | where type == "text" | get -o text | default [] | str join "")
    let tool_use_blocks = ($blocks | where type == "tool_use")
    let finish_reason = (match ($response | get -o stop_reason | default "") {
        "tool_use" => "tool_calls"
        "max_tokens" => "length"
        _ => "stop"
    })

    mut message = { role: "assistant", content: (if ($text | is-empty) { null } else { $text }) }
    if ($tool_use_blocks | is-not-empty) {
        let tool_calls = ($tool_use_blocks | each {|b| { id: $b.id, type: "function", function: { name: $b.name, arguments: ($b.input | to json) } } })
        $message = ($message | insert tool_calls $tool_calls)
    }

    { choices: [{ message: $message, finish_reason: $finish_reason }] }
}

# Call Anthropic's Messages API. Shares calloai/callama's OpenAI-shaped
# request/response contract (an OpenAI-style { messages, model_tools,
# options } record in, an OpenAI-shaped chat-completion response out) so
# agent/agents.nu and agent/internal.nu need no runtime-specific branching
# beyond model_call itself -- see openai_messages_to_anthropic /
# anthropic_response_to_openai above for the translation this requires
# (Anthropic's system-prompt-as-top-level-field, content-block-list, and
# tool_use/tool_result shapes all differ from OpenAI's).
#
# `options` passes through to the request body as-is beyond
# max_tokens/stream (handled explicitly below), so Anthropic-specific
# fields like extended thinking (`{ thinking: { type: "enabled",
# budget_tokens: N } }`) work by setting them directly in agents.json --
# note Anthropic requires max_tokens > thinking.budget_tokens and
# rejects `temperature` alongside `thinking`.
export def call_anthropic [model, messages, model_tools, options] {
    let translated = (openai_messages_to_anthropic $messages)
    let anthropic_tools = (if ($model_tools | is-empty) { [] } else { openai_tools_to_anthropic $model_tools })

    mut json = {
        model: $model,
        system: $translated.system,
        messages: $translated.messages,
        max_tokens: ($options | get -o max_tokens | default 4096)
    }
    if ($anthropic_tools | is-not-empty) {
        $json = ($json | insert tools $anthropic_tools)
    }
    let extra = ($options | reject -o max_tokens | reject -o stream)
    if ($extra | is-not-empty) {
        $json = ($json | merge $extra)
    }

    mut attempt = 0
    loop {
        $attempt = $attempt + 1

        let outcome = (try {
            let response = (http post -e -f --max-time $MODEL_CALL_TIMEOUT "https://api.anthropic.com/v1/messages" $json --headers [
                "x-api-key" $env.ANTHROPIC_API_KEY
                "anthropic-version" "2023-06-01"
            ] --content-type "application/json")
            { kind: "response", response: $response }
        } catch {|e|
            # A stalled/refused connection, DNS failure, or --max-time
            # abort raises here rather than returning a response record
            # -- e.g. the same class of failure MODEL_CALL_TIMEOUT is
            # meant to bound, just retried a few times first in case it
            # was a momentary blip rather than a real outage.
            { kind: "exception", error: $e }
        })

        if $outcome.kind == "exception" {
            if $attempt >= $MAX_ATTEMPTS {
                error make { msg: $"Anthropic API error: request failed after ($MAX_ATTEMPTS) attempts: ($outcome.error.msg)" }
            }
            retry-backoff $attempt $"Anthropic request error: ($outcome.error.msg)"
            continue
        }

        let response = $outcome.response

        # A non-2xx response body has a { type: "error", error: { message } }
        # shape rather than the { content, stop_reason } shape
        # anthropic_response_to_openai expects -- surface the actual API
        # error message via a raised error rather than let a malformed
        # `content`/`stop_reason` cascade into a confusing "Input type not
        # supported"-style crash several calls downstream.
        if ($response.body | get -o type | default "") == "error" {
            let msg = ($response.body | get -o error.message | default "unknown error")
            if ($response.status in $RETRYABLE_STATUSES) and ($attempt < $MAX_ATTEMPTS) {
                retry-backoff $attempt $"Anthropic API error \(HTTP ($response.status)\): ($msg)" $response.headers.response
                continue
            }
            error make { msg: $"Anthropic API error: ($msg)" }
        }

        return (anthropic_response_to_openai $response.body)
    }
}
