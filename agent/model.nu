use ../common/utils.nu *

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
    let response = http post  $url  $json
    $response
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
    let response = ( http post  -e -f $url $json --headers ["Authorization" $"Bearer ($env.OPENAI_API_KEY) " ]   --content-type "application/json")
    $response.body
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

    let response = (http post -e -f "https://api.anthropic.com/v1/messages" $json --headers [
        "x-api-key" $env.ANTHROPIC_API_KEY
        "anthropic-version" "2023-06-01"
    ] --content-type "application/json")

    anthropic_response_to_openai $response.body
}
