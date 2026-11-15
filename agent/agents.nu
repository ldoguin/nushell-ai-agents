# Build a runnable agent record from a config entry.
use config.nu [resolve-config]
use ../tools/runtime.nu [tool-context]
use providers/openai.nu
use providers/ollama.nu
use providers/anthropic.nu
use providers/bedrock.nu
use providers/mock.nu

# `config` is one agents.json entry (see agent/config.nu for the keys); it is
# validated first, so a bad entry fails here with a message naming the agent
# and the problem. Relative paths resolve against `--base-dir` (default: the
# current directory) -- the manifest loader passes the manifest's directory.
#
# The record is plain data plus the closure that calls the model:
#   { name, runtime, model, messages, model_call, tools, max_iterations }
# `messages` starts as just the system prompt; run-agent (agent/loop.nu)
# appends the conversation and returns it, so a conversation can be continued by
# putting the returned messages back into a new agent record.
export def agent [config: record, --name: string = "", --base-dir: string = ""] {
    let label = (if ($name | is-empty) { "agent" } else { $"agent '($name)'" })
    let base = (if ($base_dir | is-empty) { pwd } else { $base_dir })
    let config = (resolve-config $config $base $label)

    let system_prompt = (if ($config.prompt? != null) { open --raw $config.prompt } else { "" })
    let model_tools = (if ($config.model_tools? != null) { open $config.model_tools } else { [] })
    let model = ($config | get -o model | default "")
    let options = $config.options

    let model_call = (match $config.runtime {
        "openai" => {|messages| openai call $model $messages $model_tools $options }
        "ollama" => {|messages| ollama call $model $messages $model_tools $options }
        "anthropic" => {|messages| anthropic call $model $messages $model_tools $options }
        "bedrock" => {|messages| bedrock call $model $messages $model_tools $options }
        "mock" => {|messages| mock call ($config.responses? | default []) $messages }
    })

    {
        name: $name
        runtime: $config.runtime
        model: $model
        messages: (if ($system_prompt | is-empty) { [] } else { [{ role: "system", content: $system_prompt }] })
        model_call: $model_call
        tools: (tool-context $config $model_tools)
        max_iterations: $config.max_iterations
    }
}
