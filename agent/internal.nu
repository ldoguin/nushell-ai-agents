use ../common/utils.nu *
use ../tools/tools.nu *

export def call [ $agent, $message] {
    echo $agent $message | log
    mut magent = $agent
    if ($message != null) {
        $magent.messages = ($magent.messages | append {"role": "user", "content": $message})
    }
    let result =  $magent | execute
    let $msg = $result.message
    if ($msg | column_exist "tool_calls" ) {
        $magent.messages = ($magent.messages | append  $result.message )
        for $tc in ( $msg.tool_calls | enumerate) {
            let toolresponse = callTool $tc.item.function
            mut tool_call_back_msg = {"role": "tool", "name" : $tc.item.function.name , "content": $toolresponse};
            if ($tc.item | column_exist "id") {
                $tool_call_back_msg  = ( $tool_call_back_msg | merge {"id" : $tc.item.id, "tool_call_id" : $tc.item.id } )
            }
            $magent.messages = ($magent.messages | append  $tool_call_back_msg )
            #$magent.messages = ($magent.messages | append  {"role": "user", "content": $"Observation: ($toolresponse)"} )
        }
    } else if ($msg.role == "assistant" ) {
        let steps = ( $msg.content | split row  "\n" )
        let step = ($steps  | parse --regex '^(?P<step>Action|Observation|Thought|Pause): (?P<content>.*)$')
        if ($step | column_exist "step"  ) {
            for $s in ( $step | enumerate) {
                if ( $s.item.step == "Action") {
                    let tool = ( $s.item.content | parse --regex '^(?P<fname>\w+): (?P<args>.*)$')
                    let functionName = $tool.fname.0
                    let args = ( $tool.args.0  | split row , )
                    let result_tool = callTool {name: $functionName, arguments:  { "args" : $args } }
                    $magent.messages = ($magent.messages | append  {"role": "user", "content": $"Observation: ($result_tool)"} )
                }
            }
        }
        $magent.messages = ($magent.messages | append $result.message )
    }
    let rep =  {agent: $magent, result : ($result | to json )  }
    $rep
}

export def execute [] {
    mut result = do $in.model_call $in.messages
    let save_path = new_logfile
    # Only get the first choice when model propose different choices
    if ( $result | column_exist "choices" ) {
        let choice0 = $result.choices.0
        let message = ( $choice0.message | insert finish_reason  $choice0.finish_reason )
        $result = ( $result | insert message $message )
    }
    $result | to json | save $"logs/($save_path)"
    $result
}

export def parseArg [$arg] {
    if ( ( ($arg | describe ) == "string" ) and ( $arg | str index-of "{" | $in == 0 ) ) {
        let a = ( $arg | from json | (values)| str replace -r '^' '"'   | str replace -r  '$' '"' | str join ' ' )
        $a
    } else {
        let a = ( $arg |  values |  flatten | str replace -r '^' '"'   | str replace -r  '$' '"' | str join " " ) #  str replace -r '^"' '' | str replace -r  '"$' '' | 
        $a
    }
}
