use internal.nu *
use ../common/utils.nu *
use model.nu *

def build_agent [model_call: closure, prompt? : string, tool_functions? : string] {
    mut agent = {
        messages : []
        system : $prompt,
        model_call : $model_call
    }
    if ($prompt != null) {
        $agent.messages = ($agent.messages | append {"role": "system", "content": $prompt})        
    }
    if ($tool_functions != null) {
        $agent.tool_functions = $tool_functions        
    }
    $agent
}

export def agent [ config ] {
    let config = if ($config.folder? != null) {
        let config_folder = load_folder $config.folder
        ( $config | merge $config_folder)
    } else {
        $config
    }

    let base_prompt = if ($config.prompt? != null) {
        open $config.prompt
    } else {
        ""
    }
    # Optional persistent memory: a markdown file of lessons learned in
    # earlier runs (written by the `remember` tool or by the
    # self-improvement loop, see improve/README.md), appended to the
    # system prompt every time the agent is built.
    let system_prompt = if ($config.memory? != null) and ($config.memory | path exists) {
        $"($base_prompt)\n\n# Lessons from previous runs\n(open --raw $config.memory)"
    } else {
        $base_prompt
    }
    let model_tools = if ($config.model_tools? != null) {
        open $config.model_tools
    } else {
        []
    }
    mut config = $config
    $config = if ($config.options? != null) {
        $config
    } else {
        $config = $config | merge { options : {} }
        $config
    }
    let config = $config

    let built = match $config.runtime {
        "openai" => ( build_agent { |messages| calloai $config.model $messages $model_tools $config.options } $system_prompt $config.tool_functions? )
        "ollama" => ( build_agent { |messages| callama $config.model $messages false "api/chat" $model_tools $config.options } $system_prompt $config.tool_functions? )
        "anthropic" => ( build_agent { |messages| call_anthropic $config.model $messages $model_tools $config.options } $system_prompt $config.tool_functions? )
        "mock" => ( build_agent { |messages| call_mock $messages $config.options } $system_prompt $config.tool_functions? )
        _ => ( error make { msg: $"Unknown runtime '($config.runtime)' -- must be openai, ollama, anthropic or mock." } )
    }
    # Per-agent loop settings, both optional in agents.json:
    #   - tool_call_mode: "legacy" (default) or "json", see callTool
    #   - max_iterations: model round-trips run_agent allows (default 9)
    $built | merge {
        tool_call_mode: ($config.tool_call_mode? | default "legacy")
        max_iterations: ($config.max_iterations? | default 9)
    }
}

# Build and run one of the agents declared in any agents.json, by name.
# Same behaviour as agent.nu's `agent_run`, but exported from a module
# so it can be called without sourcing agent.nu.
export def run_named [agent_name: string, query: string] {
    init_logger
    let all_agents = ( ls **/agents.json | get name | reduce --fold {} { |e, acc| ( open $e | merge $acc) } )
    if not ($agent_name in ($all_agents | columns)) {
        error make { msg: $"Unknown agent '($agent_name)'." }
    }
    agent ( $all_agents | get $agent_name ) | run_agent $query
}

export def run_agent [query] {
    mut x = 0; 
    mut agent = $in
    let max_iterations = ($agent.max_iterations? | default 9)
    mut next_prompt = $query
    mut answer: any = null
    while $x < $max_iterations {
        $x = $x + 1 
        let response = call $agent $next_prompt
        let $msg = ( $response.result | from json | $in.message )
        if ( ( $msg.role == "assistant") and ( $msg.content != null ) ) {
            $msg | log
            let steps = ( $msg.content | split row  "\n" )
            let step = ($steps  | parse --regex '^(?P<step>Action|Observation|Thought|Pause|Answer): (?P<content>.*)$')
            for $s in ( $step | enumerate) {
                if ( $s.item.step == "Answer") {
                    $answer = $s.item.content
                    $answer | log
                }
            }
        }
        if ( ($msg | column_exist "finish_reason") and ( $msg.finish_reason == "stop" ) ) {
            # $agent here is still the pre-call agent object (its messages end
            # with the system prompt) -- the assistant's reply only exists on
            # $response.agent, appended inside `call`. Read from there instead
            # of $agent, otherwise this returns the system prompt, not the
            # model's actual reply.
            $answer = ( $response.agent.messages | last ).content
            return $answer
        }
        $agent = $response.agent

        $next_prompt = null

        if ( $answer != null ) {
            return $answer
        }
    }
    # sound play drop.mp3 -d 0.2sec
    $answer
}

def load_folder [folder : string] {
    let folder =  {
        "prompt":$"($folder)/prompt.txt",
        "model_tools":$"($folder)/tools.json",
        "tool_functions": $"($folder)/functions.nu"
    }
    $folder
}