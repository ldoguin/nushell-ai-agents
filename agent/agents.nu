use internal.nu *
use ../common/utils.nu *
use ../common/otel.nu *
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
    $config = if ($config.options? != null) {
        $config
    } else {
        $config = $config | merge { options : {} }
        $config
    }
    let config = $config

    match $config.runtime {
        "openai" => ( build_agent { |messages| calloai $config.model $messages $model_tools $config.options } $system_prompt $config.tool_functions? )
        "ollama" => ( build_agent { |messages| callama $config.model $messages false "api/chat" $model_tools $config.options } $system_prompt $config.tool_functions? )
        "anthropic" => ( build_agent { |messages| call_anthropic $config.model $messages $model_tools $config.options } $system_prompt $config.tool_functions? )
        "bedrock" => ( build_agent { |messages| call_bedrock $config.model $messages $model_tools $config.options } $system_prompt $config.tool_functions? )
    }
}

export def run_agent [query] {
    let max_iterations = 9
    mut x = 0;
    mut agent = $in
    # "agent.run" wraps the whole ReAct loop; $agent.otel_parent (if the
    # caller seeded one, e.g. engine.nu's run-pipeline-agent) becomes its
    # parent, otherwise this starts a fresh root trace.
    let run_span = (otel-start-span "agent.run" ($agent | get -o otel_parent | default {}))
    mut next_prompt = $query
    mut answer: any = null
    while $x < $max_iterations {
        $x = $x + 1
        # Each iteration gets its own child span, and becomes the parent
        # `call`/`execute` see for that iteration's gen_ai.chat span --
        # upsert rather than dot-assignment since a caller that never
        # seeded otel_parent at all (e.g. using this submodule directly,
        # outside engine.nu) won't have the field to assign into yet.
        let iter_span = (otel-start-span "agent.iteration" $run_span { "iteration": $x })
        $agent = ($agent | upsert otel_parent $iter_span)
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
        otel-end-span $iter_span { "finish_reason": ($msg | get -o finish_reason | default "") }
        if ( ($msg | column_exist "finish_reason") and ( $msg.finish_reason == "stop" ) ) {
            # $agent here is still the pre-call agent object (its messages end
            # with the system prompt) -- the assistant's reply only exists on
            # $response.agent, appended inside `call`. Read from there instead
            # of $agent, otherwise this returns the system prompt, not the
            # model's actual reply.
            $answer = ( $response.agent.messages | last ).content
            otel-end-span $run_span { "iterations": $x }
            return $answer
        }
        $agent = ($response.agent | upsert otel_parent $run_span)

        $next_prompt = null

        if ( $answer != null ) {
            otel-end-span $run_span { "iterations": $x }
            return $answer
        }
    }
    otel-end-span $run_span { "iterations": $x, "max_iterations_reached": true }
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