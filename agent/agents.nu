use internal.nu *
use ../common/utils.nu *
use model.nu *

def build_agent [model_call: closure, prompt? : string] {
    mut agent = {
        messages : []
        system : $prompt,
        model_call : $model_call
    }
    if ($prompt != null) {
        $agent.messages = ($agent.messages | append {"role": "system", "content": $prompt})        
    }
    $agent
}

export def qwen_general_agent [ $model_tools ] {
    let system_prompt = open agent/prompts/toolSystemPrompt.txt
    mut agent = build_agent { |messages| callama "qwen2.5:7b" $messages false "api/chat" $model_tools } $system_prompt
    $agent
}

export def qwen_code_agent [ $model_tools ] {
    let system_prompt = open agent/prompts/coder.txt
    mut agent = build_agent { |messages| callama "qwen2.5-coder" $messages false "api/chat" $model_tools } $system_prompt
    $agent
}

export def openai-mini-o_agent [ $model_tools ] {
    mut agent = build_agent { |messages| calloai $messages $model_tools }
    $agent
}

export def qwen-reasoner_agent [ $model_tools ] {
    let system_prompt = open agent/prompts/reasoner.txt
    mut agent = build_agent { |messages| calloai $messages $model_tools } $system_prompt
    $agent
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
            print $msg
            let steps = ( $msg.content | split row  "\n" )
            let step = ($steps  | parse --regex '^(?P<step>Action|Observation|Thought|Pause|Answer): (?P<content>.*)$')
            for $s in ( $step | enumerate) {
                if ( $s.item.step == "Answer") {
                    $answer = $s.item.content
                    print $answer
                }
            }
        }
        if ( ($msg | column_exist "finish_reason") and ( $msg.finish_reason == "stop" ) ) {
            print "Found the answer"
            $answer = ( $agent.messages | last ).content
            print $answer
            break;
        }
        $agent = $response.agent

        $next_prompt = null

        if ( $answer != null ) {
            print "Found the answer"
            print $answer
            break;
        }
    }
    # sound play drop.mp3 -d 0.2sec
    $answer
}