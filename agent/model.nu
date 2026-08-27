use ../common/utils.nu *
use ../common/otel.nu *

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

# Normalizes each provider's differently-shaped token-usage field into
# OpenAI's {prompt_tokens, completion_tokens, total_tokens} naming -- the
# convention every other part of this file already normalizes responses
# toward. Anthropic's Messages API and Bedrock's Converse API both discard
# usage today before this existed (translated away by
# anthropic_response_to_openai/converse_response_to_openai below, which
# only ever read content/stop_reason) -- this fixes that as a side effect
# of adding it once here, rather than duplicating token-usage extraction
# in all four provider functions individually.
def normalize-usage [runtime: string, raw: record] {
    match $runtime {
        "anthropic" => {
            prompt_tokens: ($raw | get -o usage.input_tokens | default 0)
            completion_tokens: ($raw | get -o usage.output_tokens | default 0)
            total_tokens: (($raw | get -o usage.input_tokens | default 0) + ($raw | get -o usage.output_tokens | default 0))
        }
        "bedrock" => {
            prompt_tokens: ($raw | get -o usage.inputTokens | default 0)
            completion_tokens: ($raw | get -o usage.outputTokens | default 0)
            total_tokens: ($raw | get -o usage.totalTokens | default 0)
        }
        # Ollama's /api/chat has no `usage` object at all -- these two
        # top-level fields are its equivalent.
        "ollama" => {
            prompt_tokens: ($raw | get -o prompt_eval_count | default 0)
            completion_tokens: ($raw | get -o eval_count | default 0)
            total_tokens: (($raw | get -o prompt_eval_count | default 0) + ($raw | get -o eval_count | default 0))
        }
        _ => ($raw | get -o usage | default { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 })  # openai: already OpenAI-shaped
    }
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

        return ($outcome.response | upsert usage (normalize-usage "ollama" $outcome.response))
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

        return ($response.body | upsert usage (normalize-usage "openai" $response.body))
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

# Translate an OpenAI-style tools.json entry list into Bedrock Converse's
# toolConfig.tools shape ([{toolSpec:{name,description,inputSchema:{json}}}]).
def openai_tools_to_converse [model_tools: list] {
    $model_tools | each {|t|
        {
            toolSpec: {
                name: $t.function.name
                description: ($t.function | get -o description | default "")
                inputSchema: { json: $t.function.parameters }
            }
        }
    }
}

# Translate this repo's OpenAI-shaped message list into Bedrock Converse's
# { system, messages } request shape -- the same translation
# openai_messages_to_anthropic does for Anthropic's Messages API, adapted
# to Converse's own block shapes:
#   - system-role message(s) become the top-level `system` field, a list
#     of {text} blocks (Converse's system field is a block list, not the
#     plain string Anthropic's Messages API takes)
#   - "tool"-role messages become user-role toolResult blocks
#   - assistant messages carrying `tool_calls` get their toolUse blocks
#     rebuilt from those entries
#   - adjacent entries mapping to the same Converse role are merged into
#     one message, since Converse rejects two consecutive same-role
#     messages the same way Anthropic's Messages API does
def openai_messages_to_converse [messages: list] {
    let system_text = ($messages | where role == "system" | get content | str join "\n\n")
    let system = (if ($system_text | is-empty) { [] } else { [{ text: $system_text }] })
    let converted = ($messages | where role != "system" | each {|m|
        match $m.role {
            "tool" => {
                role: "user"
                content: [{
                    toolResult: {
                        toolUseId: ($m | get -o tool_call_id | default ($m | get -o id | default ""))
                        content: [{ text: ($m | get -o content | default "") }]
                    }
                }]
            }
            "assistant" => (
                if ($m | get -o tool_calls | default [] | is-not-empty) {
                    let text_blocks = (if ($m | get -o content | default "" | is-empty) { [] } else { [{ text: $m.content }] })
                    let tool_blocks = ($m.tool_calls | each {|tc| { toolUse: { toolUseId: $tc.id, name: $tc.function.name, input: ($tc.function.arguments | from json) } } })
                    { role: "assistant", content: ($text_blocks | append $tool_blocks) }
                } else {
                    { role: "assistant", content: [{ text: ($m | get -o content | default "") }] }
                }
            )
            _ => { role: "user", content: [{ text: ($m | get -o content | default "") }] }
        }
    })

    mut merged = []
    for m in $converted {
        if ($merged | is-not-empty) and (($merged | last).role == $m.role) {
            let prev = ($merged | last)
            $merged = ($merged | drop 1 | append { role: $m.role, content: ($prev.content | append $m.content) })
        } else {
            $merged = ($merged | append $m)
        }
    }
    { system: $system, messages: $merged }
}

# Translate Bedrock Converse's { output: { message: { content } },
# stopReason } response shape back into an OpenAI-shaped
# { choices: [{ message, finish_reason }] } response -- the same contract
# anthropic_response_to_openai produces, so every downstream consumer
# (agent/internal.nu's execute/call, run_agent's ReAct loop) stays
# runtime-agnostic regardless of provider.
def converse_response_to_openai [response: record] {
    let blocks = ($response | get -o output.message.content | default [])
    let text = ($blocks | where {|b| ($b | get -o text | default null) != null } | get -o text | default [] | str join "")
    let tool_use_blocks = ($blocks | where {|b| ($b | get -o toolUse | default null) != null } | get toolUse)
    let finish_reason = (match ($response | get -o stopReason | default "") {
        "tool_use" => "tool_calls"
        "max_tokens" => "length"
        _ => "stop"
    })

    mut message = { role: "assistant", content: (if ($text | is-empty) { null } else { $text }) }
    if ($tool_use_blocks | is-not-empty) {
        let tool_calls = ($tool_use_blocks | each {|b| { id: $b.toolUseId, type: "function", function: { name: $b.name, arguments: ($b.input | to json) } } })
        $message = ($message | insert tool_calls $tool_calls)
    }

    { choices: [{ message: $message, finish_reason: $finish_reason }] }
}

# http post's own error message for anything raised before a response is
# received (dropped connection, TLS failure, DNS, but ALSO a malformed
# request the HTTP client itself refuses to send, e.g. a header value
# containing a stray newline) is a generic "Network failure" string --
# nu's ShellError::NetworkFailure display, shared across every one of
# those cases. That's misleading enough to cost real debugging time: an
# 8-attempt exponential-backoff retry loop treating a non-transient,
# guaranteed-to-repeat request-construction error (like a corrupted
# bearer token containing a trailing newline -- confirmed live, see
# ldoguin/nushell-ai-agents#9) as if it might be a flaky connection.
# The actually-useful detail nu's http client attaches (e.g. "protocol:
# authorization header is not a string") lives in the error's `json`
# field's first label, not `.msg` -- pull it out so retry-backoff/the
# final error message says the real thing instead of "Network failure"
# eight times in a row.
def bedrock-exception-detail [e: record] {
    let label = (try {
        ($e | get -o json | default "" | from json | get -o labels.0.text | default "")
    } catch { "" })
    if ($label | is-not-empty) and ($label != $e.msg) {
        $"($e.msg) -- ($label)"
    } else {
        $e.msg
    }
}

# Call Amazon Bedrock's Converse API using a Bedrock API key (a bearer
# token, generated in the Bedrock console) rather than IAM SigV4 request
# signing -- this keeps the call a plain HTTPS POST shaped like
# call_anthropic/calloai instead of needing the AWS CLI or a hand-rolled
# signing implementation. Converse is Bedrock's provider-agnostic
# inference API (unlike InvokeModel, whose request/response body is
# different for every model family), so this one function covers any
# model Bedrock hosts. Shares calloai/callama/call_anthropic's
# OpenAI-shaped request/response contract -- see
# openai_messages_to_converse / converse_response_to_openai above for the
# translation this requires.
#
# `model` is a Bedrock model ID or cross-region inference profile ID
# (e.g. "us.anthropic.claude-opus-4-5-20250929-v1:0" -- on-demand
# "serverless" usage of Anthropic's newer models on Bedrock requires the
# inference-profile form, not the bare model ID). Requires
# $env.AWS_BEARER_TOKEN_BEDROCK (a Bedrock API key) and $env.AWS_REGION
# (or $env.AWS_DEFAULT_REGION, the AWS CLI/SDKs' own fallback var).
export def call_bedrock [model, messages, model_tools, options] {
    # AWS_REGION takes precedence over AWS_DEFAULT_REGION when both are
    # set, matching the AWS CLI/SDKs' own resolution order.
    mut region = ($env.AWS_REGION? | default "")
    if ($region | is-empty) {
        $region = ($env.AWS_DEFAULT_REGION? | default "")
    }
    if ($region | is-empty) {
        error make { msg: "Bedrock API error: neither AWS_REGION nor AWS_DEFAULT_REGION is set" }
    }
    if ($env.AWS_BEARER_TOKEN_BEDROCK? | default "" | is-empty) {
        error make { msg: "Bedrock API error: AWS_BEARER_TOKEN_BEDROCK is not set" }
    }

    let translated = (openai_messages_to_converse $messages)
    let bedrock_tools = (if ($model_tools | is-empty) { [] } else { openai_tools_to_converse $model_tools })

    mut inference_config = { maxTokens: ($options | get -o max_tokens | default 4096) }
    let temperature = ($options | get -o temperature | default null)
    if $temperature != null {
        $inference_config = ($inference_config | insert temperature $temperature)
    }

    mut json = {
        messages: $translated.messages
        inferenceConfig: $inference_config
    }
    if ($translated.system | is-not-empty) {
        $json = ($json | insert system $translated.system)
    }
    if ($bedrock_tools | is-not-empty) {
        $json = ($json | insert toolConfig { tools: $bedrock_tools })
    }
    # additionalModelRequestFields is Converse's passthrough for
    # model-specific fields Converse itself doesn't standardize --
    # notably Anthropic's `thinking` (extended-thinking budget), the
    # same field the direct Anthropic Messages API takes at the top
    # level. See translate-bedrock-options in .github/scripts/agents/engine.nu.
    let additional_fields = ($options | get -o additionalModelRequestFields | default {})
    if ($additional_fields | is-not-empty) {
        $json = ($json | insert additionalModelRequestFields $additional_fields)
    }

    let url = $"https://bedrock-runtime.($region).amazonaws.com/model/($model | url encode)/converse"

    mut attempt = 0
    loop {
        $attempt = $attempt + 1

        let outcome = (try {
            let response = (http post -e -f --max-time $MODEL_CALL_TIMEOUT $url $json --headers [
                "Authorization" $"Bearer ($env.AWS_BEARER_TOKEN_BEDROCK)"
            ] --content-type "application/json")
            { kind: "response", response: $response }
        } catch {|e|
            { kind: "exception", error: (bedrock-exception-detail $e) }
        })

        if $outcome.kind == "exception" {
            if $attempt >= $MAX_ATTEMPTS {
                error make { msg: $"Bedrock API error: request failed after ($MAX_ATTEMPTS) attempts: ($outcome.error)" }
            }
            retry-backoff $attempt $"Bedrock request error: ($outcome.error)"
            continue
        }

        let response = $outcome.response

        if ($response.status >= 300) {
            let msg = ($response.body | get -o message | default ($response.body | get -o Message | default "unknown error"))
            if ($response.status in $RETRYABLE_STATUSES) and ($attempt < $MAX_ATTEMPTS) {
                retry-backoff $attempt $"Bedrock API error \(HTTP ($response.status)\): ($msg)" $response.headers.response
                continue
            }
            error make { msg: $"Bedrock API error: ($msg)" }
        }

        return ((converse_response_to_openai $response.body) | upsert usage (normalize-usage "bedrock" $response.body))
    }
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

        return ((anthropic_response_to_openai $response.body) | upsert usage (normalize-usage "anthropic" $response.body))
    }
}
