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
    let system_prompt = if ($config.prompt? != null) {
        open $config.prompt
    } else {
        ""
    }
    let model_tools = if ($config.model_tools? != null) {
        open $config.model_tools
    } else {
        []
    }
    mut config = $config
    $config.options = if ($config.options? != null) {
        $config.options
    } else {
        {}
    }
    let config = $config

    match $config.runtime {
        "openai" => ( build_agent { |messages| calloai $config.model $messages $model_tools $config.options } $system_prompt $config.tool_functions? )
        "ollama" => ( build_agent { |messages| callama $config.model $messages false "api/chat" $model_tools $config.options } $system_prompt $config.tool_functions? )
    }
}

export def run_agent [query] {
    let max_iterations = 9
    mut x = 0; 
    mut agent = $in
    mut next_prompt = $query
    mut answer = null
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
            $answer = ( $agent.messages | last ).content
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