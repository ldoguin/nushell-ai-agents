# Anthropic's Messages API -- and any server that speaks it (LiteLLM's
# /v1/messages, ...). Translates the repo's OpenAI-shaped conversation to and
# from Anthropic's shapes:
#   - system messages become the top-level `system` field
#   - "tool" messages become user-role tool_result blocks
#   - assistant messages carrying tool_calls get their tool_use blocks rebuilt
#   - adjacent same-role messages are merged (Anthropic rejects consecutive
#     messages with one role; the repo appends one "tool" message per result)
#
# `options` passes through to the request body beyond max_tokens/stream, so
# Anthropic-only fields work from agents.json -- e.g. extended thinking
# `{ thinking: { type: "enabled", budget_tokens: N } }` (Anthropic requires
# max_tokens > budget_tokens and rejects `temperature` alongside it).
#
# ANTHROPIC_BASE_URL (optional) follows the Anthropic SDKs' convention of
# omitting the version segment, e.g. http://litellm:4000; a trailing /v1 is
# tolerated. Unset: api.anthropic.com.
use ../http.nu *

def tools-to-anthropic [model_tools: list] {
    $model_tools | each {|t|
        {
            name: $t.function.name
            description: ($t.function | get -o description | default "")
            input_schema: $t.function.parameters
        }
    }
}

def messages-to-anthropic [messages: list] {
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
                    let tool_blocks = ($m.tool_calls | each {|tc| { type: "tool_use", id: $tc.id, name: $tc.function.name, input: (tool-arguments $tc.function.arguments) } })
                    { role: "assistant", content: ($text_blocks | append $tool_blocks) }
                } else {
                    { role: "assistant", content: ($m | get -o content | default "") }
                }
            )
            _ => { role: "user", content: ($m | get -o content | default "") }
        }
    })
    let as_blocks = {|c| if ($c | describe) == "string" { [{ type: "text", text: $c }] } else { $c } }
    { system: $system, messages: (merge-adjacent-roles $converted $as_blocks) }
}

def from-anthropic [body: record] {
    let blocks = ($body | get -o content | default [])
    let text = ($blocks | where type == "text" | get -o text | default [] | str join "")
    let tool_use = ($blocks | where type == "tool_use")
    let finish = (match ($body | get -o stop_reason | default "") {
        "tool_use" => "tool_calls"
        "max_tokens" => "length"
        _ => "stop"
    })

    mut message = { role: "assistant", content: (if ($text | is-empty) { null } else { $text }) }
    if ($tool_use | is-not-empty) {
        $message = ($message | insert tool_calls ($tool_use | each {|b| { id: $b.id, type: "function", function: { name: $b.name, arguments: ($b.input | to json) } } }))
    }
    let input = ($body | get -o usage.input_tokens | default 0)
    let output = ($body | get -o usage.output_tokens | default 0)
    {
        choices: [{ message: $message, finish_reason: $finish }]
        usage: { prompt_tokens: $input, completion_tokens: $output, total_tokens: ($input + $output) }
    }
}

# What is wrong with this reply, or null if it is usable.
def check-reply [r: record] {
    # A non-2xx body is { type: "error", error: { message } }; a proxy
    # (LiteLLM) reports its own failures -- spent key budget, bad key, unknown
    # model alias -- as { error: { message, type, code } } with no top-level
    # `type`. Either way say what the server said rather than let a missing
    # `content` cascade into a confusing crash several calls downstream.
    let message = ($r.body | get -o error.message | default "")
    if ($r.body | get -o type | default "") == "error" or $r.status >= 300 or ($message | is-not-empty) {
        let detail = (if ($r.body | get -o type | default "") == "error" { "" } else { $r.body | get -o error.type | default "error" })
        return (api-error "Anthropic" $r (if ($message | is-empty) { "unknown error" } else { $message }) $detail)
    }

    # A 200 with neither a text nor a tool_use block (only thinking, a refusal,
    # or a reply cut off by max_tokens while thinking) would reach the loop
    # with `content: null`. Retry a plain end_turn once or twice in case it was
    # a one-off, then fail with what the API actually said.
    let blocks = ($r.body | get -o content | default [])
    if ($blocks | where type in ["text" "tool_use"] | is-not-empty) {
        return null
    }
    let stop_reason = ($r.body | get -o stop_reason | default "")
    let types = ($blocks | get -o type | default [] | str join ",")
    let output_tokens = ($r.body | get -o usage.output_tokens | default 0)
    let stop_details = ($r.body | get -o stop_details | default null)
    let detail = (if $stop_details == null {
        $"stop_reason: ($stop_reason), content blocks: [($types)], output_tokens: ($output_tokens)"
    } else {
        $"stop_reason: ($stop_reason), stop_details: ($stop_details | to json --raw), content blocks: [($types)], output_tokens: ($output_tokens)"
    })
    # No stop_reason at all means the body was not a message (an empty or
    # foreign reply from the endpoint or a proxy): treat it like an end_turn
    # with no text, and show what actually came back.
    let malformed = ($stop_reason | is-empty)
    let raw = (if $malformed { $" -- raw body: ($r.body | to json --raw | str substring 0..<300)" } else { "" })
    let text = $"Anthropic returned no text \(($detail)\)($raw)"
    { retryable: ($stop_reason == "end_turn" or $malformed), max_attempts: 3, label: $text, error: $text }
}

export def call [model: string, messages: list, model_tools: list, options: record] {
    require-env ANTHROPIC_API_KEY "Anthropic"
    let base = (provider-base-url "ANTHROPIC_BASE_URL" "https://api.anthropic.com" | str replace --regex '/v1$' '')
    let translated = (messages-to-anthropic $messages)

    let body = ({
            model: $model
            system: $translated.system
            messages: $translated.messages
            max_tokens: ($options | get -o max_tokens | default 4096)
        }
        | merge (if ($model_tools | is-empty) { {} } else { { tools: (tools-to-anthropic $model_tools) } })
        | merge ($options | reject -o max_tokens | reject -o stream))

    call-provider {
        name: "Anthropic"
        url: $"($base)/v1/messages"
        headers: ["x-api-key" $env.ANTHROPIC_API_KEY "anthropic-version" "2023-06-01"]
        body: $body
        check: {|r| check-reply $r }
        parse: {|r| from-anthropic $r.body }
    }
}
