# A local Ollama server's /api/chat. OLLAMA_BASE_URL (default
# http://localhost:11434) points it elsewhere.
#
# Ollama differs from the canonical (OpenAI-shaped) format in three ways, all
# handled here: tool-call arguments are objects, not JSON strings; tool calls
# carry no ids; and usage lives in prompt_eval_count/eval_count.
use ../http.nu *

# Canonical -> Ollama: tool-call arguments back to objects, ids dropped.
def to-ollama-messages [messages: list] {
    $messages | each {|m|
        let calls = ($m | get -o tool_calls | default [])
        if ($calls | is-empty) {
            $m
        } else {
            $m | upsert tool_calls ($calls | each {|c| { function: { name: $c.function.name, arguments: (tool-arguments $c.function.arguments) } } })
        }
    }
}

# Ollama -> canonical.
def from-ollama [body: record] {
    let message = ($body | get -o message | default { role: "assistant", content: "" })
    let calls = ($message | get -o tool_calls | default [])
    let content = ($message | get -o content | default "")
    mut out = { role: "assistant", content: (if ($content | is-empty) { null } else { $content }) }
    mut finish = (if ($body | get -o done_reason | default "stop") == "length" { "length" } else { "stop" })
    if ($calls | is-not-empty) {
        $out = ($out | insert tool_calls ($calls | enumerate | each {|c|
            { id: $"call_($c.index)", type: "function", function: { name: $c.item.function.name, arguments: ($c.item.function.arguments | to json) } }
        }))
        $finish = "tool_calls"
    }
    let prompt = ($body | get -o prompt_eval_count | default 0)
    let completion = ($body | get -o eval_count | default 0)
    {
        choices: [{ message: $out, finish_reason: $finish }]
        usage: { prompt_tokens: $prompt, completion_tokens: $completion, total_tokens: ($prompt + $completion) }
    }
}

export def call [model: string, messages: list, model_tools: list, options: record] {
    let base = (provider-base-url "OLLAMA_BASE_URL" "http://localhost:11434")
    let body = ({ model: $model, messages: (to-ollama-messages $messages), stream: false, options: { temperature: 0 } }
        | merge (if ($model_tools | is-empty) { {} } else { { tools: $model_tools } })
        | merge $options)

    call-provider {
        name: "Ollama"
        url: $"($base)/api/chat"
        headers: []
        body: $body
        check: {|r|
            if $r.status >= 300 {
                # { error: "model 'x' not found" } -- a string, not an object
                api-error "Ollama" $r ($r.body | get -o error | default "unknown error" | into string)
            }
        }
        parse: {|r| from-ollama $r.body }
    }
}
