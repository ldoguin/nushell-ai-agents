# Deterministic, offline "provider" for tests and demos: replays a scripted
# conversation instead of calling a model. The Nth model call returns
# script[N], where N is the number of assistant messages already in the
# conversation -- derived from the messages themselves so the closure needs
# no mutable state. Script items:
#   "text"                                  -> a plain assistant reply
#   { content: "text", finish_reason: "length" }  -> reply with a given finish
#   { tool_calls: [{ name, arguments }] }   -> native tool calls (arguments is
#                                              a record or a JSON string)
#   { error: "message" }                    -> the call raises this error
# Running past the end of the script is an error, so a loop that does not
# stop where a test expects fails loudly instead of repeating itself.
export def call [script: list, messages: list] {
    let turn = ($messages | where role == "assistant" | length)
    let item = ($script | get -o $turn | default null)
    if $item == null {
        error make { msg: $"Mock provider: no scripted response for model call ($turn + 1) \(script has ($script | length)\)" }
    }
    let usage = { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
    if ($item | describe) == "string" {
        return { choices: [{ message: { role: "assistant", content: $item }, finish_reason: "stop" }], usage: $usage, retry_attempts: 1 }
    }
    let err = ($item | get -o error | default null)
    if $err != null {
        error make { msg: $err }
    }
    let calls = ($item | get -o tool_calls | default [])
    if ($calls | is-not-empty) {
        let tool_calls = ($calls | enumerate | each {|c|
            let args = ($c.item | get -o arguments | default {})
            {
                id: $"call_($turn)_($c.index)"
                type: "function"
                function: { name: $c.item.name, arguments: (if ($args | describe) == "string" { $args } else { $args | to json }) }
            }
        })
        let content = ($item | get -o content | default null)
        return { choices: [{ message: { role: "assistant", content: $content, tool_calls: $tool_calls }, finish_reason: "tool_calls" }], usage: $usage, retry_attempts: 1 }
    }
    { choices: [{ message: { role: "assistant", content: ($item | get -o content | default null) }, finish_reason: ($item | get -o finish_reason | default "stop") }], usage: $usage, retry_attempts: 1 }
}
