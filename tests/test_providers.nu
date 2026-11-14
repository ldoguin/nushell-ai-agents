# Provider behaviour, exercised end to end against a scripted fake server:
# request shape, response translation, usage, retry and error handling.
use std/assert
use lib.nu *
use ../agent/providers/openai.nu
use ../agent/providers/ollama.nu
use ../agent/providers/anthropic.nu
use ../agent/providers/bedrock.nu
use ../agent/providers/mock.nu
use ../agent/http.nu [retry-delay]

const MSGS = [
    { role: "system", content: "be brief" }
    { role: "user", content: "hi" }
]

const OVERLOADED = {
    status: 529
    headers: { retry-after: "0" }
    body: { type: "error", error: { type: "overloaded_error", message: "Overloaded" } }
}

def with-anthropic [base: string, action: closure] {
    with-env { ANTHROPIC_BASE_URL: $base, ANTHROPIC_API_KEY: "sk-test", OTEL_SDK_DISABLED: "true" } { do $action }
}

# ---------------------------------------------------------------- anthropic

export def test-anthropic-text-reply [] {
    let r = (fake-llm [(anthropic-text "hello")] {|base|
        with-anthropic $base { anthropic call "claude-x" $MSGS [] { max_tokens: 100 } }
    })
    assert $r.ok $r.error
    let msg = $r.value.choices.0.message
    assert equal $msg.content "hello"
    assert equal $r.value.choices.0.finish_reason "stop"
    assert equal $r.value.usage { prompt_tokens: 7, completion_tokens: 3, total_tokens: 10 }

    let req = $r.requests.0
    assert equal $req.path "/v1/messages"
    assert equal $req.headers."x-api-key" "sk-test"
    assert equal $req.headers."anthropic-version" "2023-06-01"
    assert equal $req.body.model "claude-x"
    assert equal $req.body.max_tokens 100
    assert equal $req.body.system "be brief"
    assert equal $req.body.messages [{ role: "user", content: "hi" }]
}

export def test-anthropic-tool-use-round-trip [] {
    let tool_reply = { status: 200, body: {
        type: "message", role: "assistant", stop_reason: "tool_use"
        content: [{ type: "tool_use", id: "toolu_1", name: "lookup", input: { q: "x" } }]
        usage: { input_tokens: 1, output_tokens: 1 }
    } }
    let tools = [{ type: "function", function: { name: "lookup", description: "d", parameters: { type: "object", properties: { q: { type: "string" } } } } }]
    let r = (fake-llm [$tool_reply (anthropic-text "done")] {|base|
        with-anthropic $base {
            let first = (anthropic call "claude-x" $MSGS $tools {})
            let msg = $first.choices.0.message
            let followup = ($MSGS | append $msg | append { role: "tool", name: "lookup", content: "42", tool_call_id: $msg.tool_calls.0.id })
            { first: $first, second: (anthropic call "claude-x" $followup $tools {}) }
        }
    })
    assert $r.ok $r.error

    assert equal $r.value.first.choices.0.finish_reason "tool_calls"
    let call = $r.value.first.choices.0.message.tool_calls.0
    assert equal $call.id "toolu_1"
    assert equal $call.function.name "lookup"
    assert equal ($call.function.arguments | from json) { q: "x" }
    assert equal $r.value.second.choices.0.message.content "done"

    # tools are translated to Anthropic's shape...
    assert equal $r.requests.0.body.tools.0.name "lookup"
    assert equal $r.requests.0.body.tools.0.input_schema.type "object"
    # ...and the tool turn comes back as an assistant tool_use + user tool_result
    let sent = $r.requests.1.body.messages
    assert equal ($sent | get role) ["user" "assistant" "user"]
    assert equal $sent.1.content.0 { type: "tool_use", id: "toolu_1", name: "lookup", input: { q: "x" } }
    assert equal $sent.2.content.0 { type: "tool_result", tool_use_id: "toolu_1", content: "42" }
}

export def test-anthropic-merges-parallel-tool-results [] {
    let assistant = { role: "assistant", content: null, tool_calls: [
        { id: "a", type: "function", function: { name: "t", arguments: "{}" } }
        { id: "b", type: "function", function: { name: "t", arguments: "{}" } }
    ] }
    let msgs = ($MSGS | append $assistant | append [
        { role: "tool", name: "t", content: "ra", tool_call_id: "a" }
        { role: "tool", name: "t", content: "rb", tool_call_id: "b" }
    ])
    let r = (fake-llm [(anthropic-text "ok")] {|base| with-anthropic $base { anthropic call "claude-x" $msgs [] {} } })
    assert $r.ok $r.error
    # Anthropic rejects consecutive same-role messages: both results must share one user turn.
    let sent = $r.requests.0.body.messages
    assert equal ($sent | get role) ["user" "assistant" "user"]
    assert equal ($sent.2.content | get tool_use_id) ["a" "b"]
}

export def test-anthropic-retries-overload-honoring-retry-after [] {
    let r = (fake-llm [$OVERLOADED (anthropic-text "recovered")] {|base|
        with-anthropic $base { anthropic call "claude-x" $MSGS [] {} }
    })
    assert $r.ok $r.error
    assert equal $r.value.choices.0.message.content "recovered"
    assert equal $r.value.retry_attempts 2
    assert equal ($r.requests | length) 2
}

export def test-anthropic-does-not-retry-client-errors [] {
    let bad = { status: 400, body: { type: "error", error: { type: "invalid_request_error", message: "max_tokens too large" } } }
    let r = (fake-llm [$bad (anthropic-text "never")] {|base| with-anthropic $base { anthropic call "claude-x" $MSGS [] {} } })
    assert (not $r.ok)
    assert ($r.error | str contains "max_tokens too large")
    assert equal ($r.requests | length) 1
}

export def test-anthropic-surfaces-proxy-errors [] {
    let proxy = { status: 401, body: { error: { message: "key budget exceeded", type: "budget_exceeded" } } }
    let r = (fake-llm [$proxy] {|base| with-anthropic $base { anthropic call "claude-x" $MSGS [] {} } })
    assert (not $r.ok)
    assert ($r.error | str contains "key budget exceeded")
    assert equal ($r.requests | length) 1
}

export def test-anthropic-records-proxy-cost-headers [] {
    let reply = ((anthropic-text "hi") | insert headers { "x-litellm-response-cost": "8.3e-06", "x-litellm-key-spend": "1.5" })
    let r = (fake-llm [$reply] {|base| with-anthropic $base { anthropic call "claude-x" $MSGS [] {} } })
    assert $r.ok $r.error
    assert equal $r.value.cost.cost_usd 8.3e-06
    assert equal $r.value.cost.key_spend 1.5
    assert equal $r.value.cost.key_max_budget null
}

export def test-anthropic-base-url-tolerates-trailing-v1 [] {
    let r = (fake-llm [(anthropic-text "hi")] {|base|
        with-anthropic $"($base)/v1/" { anthropic call "claude-x" $MSGS [] {} }
    })
    assert $r.ok $r.error
    assert equal $r.requests.0.path "/v1/messages"
}

# ------------------------------------------------------------------- openai

export def test-openai-text-reply-and-auth [] {
    let reply = { status: 200, body: { choices: [{ message: { role: "assistant", content: "hello" }, finish_reason: "stop" }], usage: { prompt_tokens: 4, completion_tokens: 2, total_tokens: 6 } } }
    let r = (fake-llm [$reply] {|base|
        with-env { OPENAI_BASE_URL: $"($base)/v1", OPENAI_API_KEY: "sk-oai" } {
            openai call "gpt-x" $MSGS [] { temperature: 0 }
        }
    })
    assert $r.ok $r.error
    assert equal $r.value.choices.0.message.content "hello"
    assert equal $r.value.usage.total_tokens 6
    assert equal $r.requests.0.path "/v1/chat/completions"
    # no stray whitespace in the bearer token
    assert equal $r.requests.0.headers.authorization "Bearer sk-oai"
    assert equal $r.requests.0.body.temperature 0
    assert equal $r.requests.0.body.model "gpt-x"
}

export def test-openai-retries-rate-limit [] {
    let limited = { status: 429, headers: { retry-after: "0" }, body: { error: { message: "slow down", type: "rate_limit" } } }
    let ok = { status: 200, body: { choices: [{ message: { role: "assistant", content: "fine" }, finish_reason: "stop" }] } }
    let r = (fake-llm [$limited $ok] {|base|
        with-env { OPENAI_BASE_URL: $"($base)/v1", OPENAI_API_KEY: "k" } { openai call "gpt-x" $MSGS [] {} }
    })
    assert $r.ok $r.error
    assert equal $r.value.choices.0.message.content "fine"
    assert equal ($r.requests | length) 2
}

export def test-openai-raises-on-non-retryable-error [] {
    let bad = { status: 401, body: { error: { message: "Incorrect API key provided", type: "invalid_request_error" } } }
    let r = (fake-llm [$bad] {|base|
        with-env { OPENAI_BASE_URL: $"($base)/v1", OPENAI_API_KEY: "wrong" } { openai call "gpt-x" $MSGS [] {} }
    })
    assert (not $r.ok) "a 401 must raise instead of returning the error body as if it were a reply"
    assert ($r.error | str contains "Incorrect API key")
    assert equal ($r.requests | length) 1
}

# ------------------------------------------------------------------ bedrock

export def test-bedrock-converse-round-trip [] {
    let reply = { status: 200, body: {
        output: { message: { role: "assistant", content: [{ text: "hola" }] } }
        stopReason: "end_turn"
        usage: { inputTokens: 5, outputTokens: 2, totalTokens: 7 }
    } }
    let r = (fake-llm [$reply] {|base|
        with-env { BEDROCK_BASE_URL: $base, AWS_REGION: "us-west-2", AWS_BEARER_TOKEN_BEDROCK: "brk", OTEL_SDK_DISABLED: "true" } {
            bedrock call "us.anthropic.claude-haiku-4-5-20251001-v1:0" $MSGS [] { max_tokens: 50, temperature: 0.2 }
        }
    })
    assert $r.ok $r.error
    assert equal $r.value.choices.0.message.content "hola"
    assert equal $r.value.usage { prompt_tokens: 5, completion_tokens: 2, total_tokens: 7 }
    let req = $r.requests.0
    # (nu's `url encode` percent-escapes "-"; compare what the server decodes)
    assert equal ($req.path | url decode) "/model/us.anthropic.claude-haiku-4-5-20251001-v1:0/converse"
    assert equal $req.headers.authorization "Bearer brk"
    assert equal $req.body.system [{ text: "be brief" }]
    assert equal $req.body.messages [{ role: "user", content: [{ text: "hi" }] }]
    assert equal $req.body.inferenceConfig { maxTokens: 50, temperature: 0.2 }
}

export def test-bedrock-tool-use-translation [] {
    let reply = { status: 200, body: {
        output: { message: { role: "assistant", content: [{ toolUse: { toolUseId: "tu1", name: "lookup", input: { q: 1 } } }] } }
        stopReason: "tool_use"
        usage: { inputTokens: 1, outputTokens: 1, totalTokens: 2 }
    } }
    let r = (fake-llm [$reply] {|base|
        with-env { BEDROCK_BASE_URL: $base, AWS_REGION: "us-west-2", AWS_BEARER_TOKEN_BEDROCK: "brk", OTEL_SDK_DISABLED: "true" } {
            bedrock call "m" $MSGS [{ type: "function", function: { name: "lookup", description: "d", parameters: { type: "object" } } }] {}
        }
    })
    assert $r.ok $r.error
    assert equal $r.value.choices.0.finish_reason "tool_calls"
    assert equal $r.value.choices.0.message.tool_calls.0.id "tu1"
    assert equal $r.requests.0.body.toolConfig.tools.0.toolSpec.name "lookup"
}

export def test-bedrock-raises-with-api-message [] {
    let bad = { status: 400, body: { message: "The provided model identifier is invalid." } }
    let r = (fake-llm [$bad] {|base|
        with-env { BEDROCK_BASE_URL: $base, AWS_REGION: "us-west-2", AWS_BEARER_TOKEN_BEDROCK: "brk", OTEL_SDK_DISABLED: "true" } { bedrock call "bad" $MSGS [] {} }
    })
    assert (not $r.ok)
    assert ($r.error | str contains "model identifier is invalid")
    assert equal ($r.requests | length) 1
}

export def test-bedrock-requires-credentials [] {
    let msg = (error-of { with-env { AWS_REGION: "us-east-1", AWS_BEARER_TOKEN_BEDROCK: "" } { bedrock call "m" $MSGS [] {} } })
    assert ($msg | str contains "AWS_BEARER_TOKEN_BEDROCK")
}

# ------------------------------------------------------------------- ollama

export def test-ollama-chat [] {
    let reply = { status: 200, body: { message: { role: "assistant", content: "yo" }, prompt_eval_count: 4, eval_count: 2 } }
    let r = (fake-llm [$reply] {|base|
        with-env { OLLAMA_BASE_URL: $base } { ollama call "qwen" $MSGS [] { temperature: 0 } }
    })
    assert $r.ok $r.error
    assert equal $r.value.choices.0.message.content "yo"
    assert equal $r.value.choices.0.finish_reason "stop"
    assert equal $r.value.usage { prompt_tokens: 4, completion_tokens: 2, total_tokens: 6 }
    assert equal $r.requests.0.path "/api/chat"
    assert equal $r.requests.0.body.model "qwen"
    assert equal $r.requests.0.body.stream false
}

# ---------------------------------------------------------------- mock

export def test-mock-replays-script-by-turn [] {
    let script = ["first" { tool_calls: [{ name: "t", arguments: { a: 1 } }] } { content: "cut", finish_reason: "length" }]
    let one = (mock call $script [{ role: "user", content: "q" }])
    assert equal $one.choices.0.message.content "first"
    let two = (mock call $script [{ role: "user", content: "q" }, { role: "assistant", content: "first" }])
    assert equal $two.choices.0.finish_reason "tool_calls"
    assert equal ($two.choices.0.message.tool_calls.0.function.arguments | from json) { a: 1 }
    assert equal $two.choices.0.message.tool_calls.0.id "call_1_0"
    let three = (mock call $script [{ role: "assistant" }, { role: "assistant" }])
    assert equal $three.choices.0.finish_reason "length"
}

export def test-mock-fails-loudly-past-end-of-script [] {
    let msg = (error-of { mock call ["only"] [{ role: "assistant" }] })
    assert ($msg | str contains "no scripted response")
}

# ------------------------------------------------- shared retry behaviour

export def test-retry-delay-backoff-and-retry-after [] {
    with-env { AGENT_RETRY_BASE_DELAY: "100ms" } {
        assert equal (retry-delay 1) 100ms
        assert equal (retry-delay 2) 200ms
        assert equal (retry-delay 4) 800ms
        assert equal (retry-delay 30) 60sec "backoff is capped"
        let header = [{ name: "Retry-After", value: "5" }]
        assert equal (retry-delay 1 $header) 5sec "the server's retry-after wins"
        assert equal (retry-delay 1 [{ name: "retry-after", value: "99999" }]) 60sec "and is capped"
        assert equal (retry-delay 2 [{ name: "retry-after", value: "soon" }]) 200ms "unparseable falls back to backoff"
    }
}

export def test-gives-up-after-max-attempts-on-persistent-overload [] {
    let r = (with-env { AGENT_RETRY_BASE_DELAY: "1ms" } {
        fake-llm [$OVERLOADED] {|base| with-anthropic $base { anthropic call "claude-x" $MSGS [] {} } }
    })
    assert (not $r.ok)
    assert ($r.error | str contains "529")
    assert ($r.error | str contains "Overloaded")
    assert equal ($r.requests | length) 8
}

export def test-retries-connection-failures-then-reports-them [] {
    let error = (with-env { AGENT_RETRY_BASE_DELAY: "1ms", ANTHROPIC_BASE_URL: "http://127.0.0.1:1", ANTHROPIC_API_KEY: "k" } {
        error-of { anthropic call "claude-x" $MSGS [] {} }
    })
    assert ($error | str contains "request failed after 8 attempts")
}

export def test-anthropic-retries-an-empty-reply-then-succeeds [] {
    let empty = { status: 200, body: { type: "message", role: "assistant", content: [], stop_reason: "end_turn", usage: { input_tokens: 5, output_tokens: 0 } } }
    let r = (with-env { AGENT_RETRY_BASE_DELAY: "1ms" } {
        fake-llm [$empty $empty (anthropic-text "finally")] {|base| with-anthropic $base { anthropic call "claude-x" $MSGS [] {} } }
    })
    assert $r.ok $r.error
    assert equal $r.value.choices.0.message.content "finally"
    assert equal $r.value.retry_attempts 3
}

export def test-anthropic-gives-up-on-persistently-empty-replies [] {
    let empty = { status: 200, body: { type: "message", role: "assistant", content: [{ type: "thinking", thinking: "hmm" }], stop_reason: "end_turn", usage: { input_tokens: 5, output_tokens: 9 } } }
    let r = (with-env { AGENT_RETRY_BASE_DELAY: "1ms" } {
        fake-llm [$empty] {|base| with-anthropic $base { anthropic call "claude-x" $MSGS [] {} } }
    })
    assert (not $r.ok)
    assert ($r.error | str contains "returned no text")
    assert ($r.error | str contains "content blocks: [thinking]")
    assert equal ($r.requests | length) 3
}

export def test-missing-api-keys-are-named [] {
    assert ((with-env { OPENAI_API_KEY: "" } { error-of { openai call "m" $MSGS [] {} } }) | str contains "OPENAI_API_KEY is not set")
    assert ((with-env { ANTHROPIC_API_KEY: "" } { error-of { anthropic call "m" $MSGS [] {} } }) | str contains "ANTHROPIC_API_KEY is not set")
}

# ------------------------------------------------- request details

export def test-openai-omits-empty-tools [] {
    let ok = { status: 200, body: { choices: [{ message: { role: "assistant", content: "x" }, finish_reason: "stop" }] } }
    let tools = [{ type: "function", function: { name: "t", description: "d", parameters: { type: "object" } } }]
    let r = (fake-llm [$ok $ok] {|base|
        with-env { OPENAI_BASE_URL: $"($base)/v1", OPENAI_API_KEY: "k" } {
            openai call "m" $MSGS [] {}
            openai call "m" $MSGS $tools {}
        }
    })
    assert $r.ok $r.error
    assert ("tools" not-in ($r.requests.0.body | columns)) "OpenAI rejects `tools: []`"
    assert equal ($r.requests.1.body.tools | length) 1
}

# ------------------------------------------------- ollama normalization

export def test-ollama-tool-calls-become-canonical [] {
    let reply = { status: 200, body: {
        message: { role: "assistant", content: "", tool_calls: [{ function: { name: "lookup", arguments: { q: "x" } } }] }
        done_reason: "stop", prompt_eval_count: 3, eval_count: 1
    } }
    let r = (fake-llm [$reply] {|base| with-env { OLLAMA_BASE_URL: $base } { ollama call "qwen" $MSGS [] {} } })
    assert $r.ok $r.error
    let choice = $r.value.choices.0
    assert equal $choice.finish_reason "tool_calls"
    assert equal $choice.message.content null
    assert equal $choice.message.tool_calls.0.id "call_0"
    assert equal ($choice.message.tool_calls.0.function.arguments | from json) { q: "x" }
}

export def test-ollama-gets-tool-arguments-as-objects-on-the-way-back [] {
    let history = ($MSGS | append { role: "assistant", content: null, tool_calls: [{ id: "call_0", type: "function", function: { name: "lookup", arguments: '{"q":"x"}' } }] } | append { role: "tool", name: "lookup", content: "42", tool_call_id: "call_0" })
    let reply = { status: 200, body: { message: { role: "assistant", content: "done" } } }
    let r = (fake-llm [$reply] {|base| with-env { OLLAMA_BASE_URL: $base } { ollama call "qwen" $history [] {} } })
    assert $r.ok $r.error
    # Ollama expects arguments as an object, not the JSON string the repo carries
    assert equal $r.requests.0.body.messages.2.tool_calls.0.function.arguments { q: "x" }
}

export def test-ollama-model-not-found-is-not-retried [] {
    let missing = { status: 404, body: { error: "model 'nope' not found" } }
    let r = (fake-llm [$missing] {|base| with-env { OLLAMA_BASE_URL: $base } { ollama call "nope" $MSGS [] {} } })
    assert (not $r.ok)
    assert ($r.error | str contains "model 'nope' not found")
    assert equal ($r.requests | length) 1
}
