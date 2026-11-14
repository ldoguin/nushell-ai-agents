# Amazon Bedrock's Converse API, authenticated with a Bedrock API key (a bearer
# token from the Bedrock console) instead of IAM SigV4 signing -- a plain HTTPS
# POST. Converse is provider-agnostic across every model Bedrock hosts, so one
# translation covers them all.
#
# `model` is a Bedrock model ID or cross-region inference profile ID, e.g.
# "us.anthropic.claude-haiku-4-5-20251001-v1:0" (on-demand use of Anthropic's
# newer models requires the inference-profile form). Needs
# $env.AWS_BEARER_TOKEN_BEDROCK and $env.AWS_REGION (or AWS_DEFAULT_REGION;
# AWS_REGION wins, as in the AWS CLI/SDKs). BEDROCK_BASE_URL overrides the
# endpoint.
use ../http.nu *

def tools-to-converse [model_tools: list] {
    $model_tools | each {|t|
        { toolSpec: { name: $t.function.name, description: ($t.function | get -o description | default ""), inputSchema: { json: $t.function.parameters } } }
    }
}

# Same translation as Anthropic's, in Converse's block shapes: `system` is a
# list of {text} blocks, tool results are toolResult blocks, tool calls are
# toolUse blocks.
def messages-to-converse [messages: list] {
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
                    let tool_blocks = ($m.tool_calls | each {|tc| { toolUse: { toolUseId: $tc.id, name: $tc.function.name, input: (tool-arguments $tc.function.arguments) } } })
                    { role: "assistant", content: ($text_blocks | append $tool_blocks) }
                } else {
                    { role: "assistant", content: [{ text: ($m | get -o content | default "") }] }
                }
            )
            _ => { role: "user", content: [{ text: ($m | get -o content | default "") }] }
        }
    })
    { system: $system, messages: (merge-adjacent-roles $converted {|c| $c }) }
}

def from-converse [body: record] {
    let blocks = ($body | get -o output.message.content | default [])
    let text = ($blocks | where {|b| ($b | get -o text | default null) != null } | get -o text | default [] | str join "")
    let tool_use = ($blocks | where {|b| ($b | get -o toolUse | default null) != null } | get toolUse)
    let finish = (match ($body | get -o stopReason | default "") {
        "tool_use" => "tool_calls"
        "max_tokens" => "length"
        _ => "stop"
    })

    mut message = { role: "assistant", content: (if ($text | is-empty) { null } else { $text }) }
    if ($tool_use | is-not-empty) {
        $message = ($message | insert tool_calls ($tool_use | each {|b| { id: $b.toolUseId, type: "function", function: { name: $b.name, arguments: ($b.input | to json) } } }))
    }
    {
        choices: [{ message: $message, finish_reason: $finish }]
        usage: {
            prompt_tokens: ($body | get -o usage.inputTokens | default 0)
            completion_tokens: ($body | get -o usage.outputTokens | default 0)
            total_tokens: ($body | get -o usage.totalTokens | default 0)
        }
    }
}

export def call [model: string, messages: list, model_tools: list, options: record] {
    let region = ($env.AWS_REGION? | default "" | if ($in | is-empty) { $env.AWS_DEFAULT_REGION? | default "" } else { $in })
    if ($region | is-empty) {
        error make { msg: "Bedrock API error: neither AWS_REGION nor AWS_DEFAULT_REGION is set" }
    }
    require-env AWS_BEARER_TOKEN_BEDROCK "Bedrock"

    let translated = (messages-to-converse $messages)
    mut inference = { maxTokens: ($options | get -o max_tokens | default 4096) }
    let temperature = ($options | get -o temperature | default null)
    if $temperature != null {
        $inference = ($inference | insert temperature $temperature)
    }
    # additionalModelRequestFields is Converse's passthrough for model-specific
    # fields it does not standardize -- notably Anthropic's `thinking`.
    let extra = ($options | get -o additionalModelRequestFields | default {})
    let body = ({ messages: $translated.messages, inferenceConfig: $inference }
        | merge (if ($translated.system | is-empty) { {} } else { { system: $translated.system } })
        | merge (if ($model_tools | is-empty) { {} } else { { toolConfig: { tools: (tools-to-converse $model_tools) } } })
        | merge (if ($extra | is-empty) { {} } else { { additionalModelRequestFields: $extra } }))

    let base = (provider-base-url "BEDROCK_BASE_URL" $"https://bedrock-runtime.($region).amazonaws.com")
    call-provider {
        name: "Bedrock"
        url: $"($base)/model/($model | url encode)/converse"
        headers: ["Authorization" $"Bearer ($env.AWS_BEARER_TOKEN_BEDROCK)"]
        body: $body
        check: {|r|
            if $r.status >= 300 {
                api-error "Bedrock" $r ($r.body | get -o message | default ($r.body | get -o Message | default "unknown error"))
            }
        }
        parse: {|r| from-converse $r.body }
    }
}
