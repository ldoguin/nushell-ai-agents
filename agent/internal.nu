use ../common/utils.nu *
use ../common/otel.nu *
use ../tools/tools.nu *

# Wraps one callTool invocation with an "execute_tool" span, per
# OpenTelemetry's GenAI semantic conventions (gen_ai.operation.name =
# execute_tool, span name `execute_tool <tool name>`, gen_ai.tool.name/
# gen_ai.tool.call.id attributes). Arguments/results are only recorded as
# span attributes when otel-capture-tool-content is enabled -- the spec
# itself flags both gen_ai.tool.call.arguments and gen_ai.tool.call.result
# as "may contain sensitive information", opt-in attributes, not
# recommended/required ones. `args_json` is expected pre-serialized (the
# native tool_calls path already carries arguments as a JSON string; the
# legacy Action:-parsing path below serializes its plain record before
# calling this). Re-raises on failure (after recording error.type and the
# error message on the span) so callTool failures propagate exactly as
# they did before this instrumentation existed -- this must never change
# what error reaches run-pipeline-agent's own try/catch, only add a span
# alongside it.
def execute-tool-with-span [name: string, call_id: string, args_json: string, tool_functions: string, parent: record, tool: record] {
    mut attrs = {
        "gen_ai.operation.name": "execute_tool"
        "gen_ai.tool.name": $name
    }
    if ($call_id | is-not-empty) {
        $attrs = ($attrs | insert "gen_ai.tool.call.id" $call_id)
    }
    if (otel-capture-tool-content) {
        $attrs = ($attrs | insert "gen_ai.tool.call.arguments" $args_json)
    }
    let span = (otel-start-span $"execute_tool ($name)" $parent $attrs)
    try {
        let result = (callTool $tool $tool_functions)
        let end_attrs = (if (otel-capture-tool-content) {
            { "gen_ai.tool.call.result": (if ($result | describe) == "string" { $result } else { $result | to json }) }
        } else {
            {}
        })
        otel-end-span $span $end_attrs
        $result
    } catch {|e|
        otel-end-span $span { "error.type": "_OTHER" } $e.msg
        error make { msg: $e.msg }
    }
}

export def call [ $agent, $message] {
    echo $agent $message | log
    mut magent = $agent
    if ($message != null) {
        $magent.messages = ($magent.messages | append {"role": "user", "content": $message})
    }
    let result =  $magent | execute
    let $msg = $result.message
    # execute_tool spans nest under the current agent.iteration (the same
    # parent this call's own gen_ai.chat span used), as a sibling of it --
    # a tool only runs after the model call it's a reply to has finished.
    let tool_parent = ($agent | get -o otel_parent | default {})
    if ($msg | column_exist "tool_calls" ) {
        $magent.messages = ($magent.messages | append  $result.message )
        for $tc in ( $msg.tool_calls | enumerate) {
            let call_id = ($tc.item | get -o id | default "")
            let toolresponse = (execute-tool-with-span $tc.item.function.name $call_id $tc.item.function.arguments $agent.tool_functions $tool_parent $tc.item.function)
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
                    let tool_call = {name: $functionName, arguments:  { "args" : $args } }
                    let result_tool = (execute-tool-with-span $functionName "" ({ "args" : $args } | to json) "tools/tools.nu" $tool_parent $tool_call)
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
    # $in.otel_parent/otel_runtime/otel_model are optional fields riding
    # along on the agent record (set by run-pipeline-agent/run_agent), not
    # part of model_call's own captured state -- reading them here needs no
    # signature changes anywhere in the call chain.
    let otel_parent = ($in | get -o otel_parent | default {})
    let otel_runtime = ($in | get -o otel_runtime | default "unknown")
    let otel_model = ($in | get -o otel_model | default "unknown")
    let span = (otel-start-span "gen_ai.chat" $otel_parent { "gen_ai.operation.name": "chat", "gen_ai.system": $otel_runtime, "gen_ai.request.model": $otel_model })

    mut result = do $in.model_call $in.messages
    let save_path = new_logfile
    # Only get the first choice when model propose different choices
    if ( $result | column_exist "choices" ) {
        let choice0 = $result.choices.0
        let message = ( $choice0.message | insert finish_reason  $choice0.finish_reason )
        $result = ( $result | insert message $message )
    }

    let usage = ($result | get -o usage | default {})
    otel-end-span $span {
        "gen_ai.usage.input_tokens": ($usage | get -o prompt_tokens | default 0)
        "gen_ai.usage.output_tokens": ($usage | get -o completion_tokens | default 0)
    }

    $result | to json | save $"logs/($save_path)"
    $result
}

export def parseArg [$arg] {
    if ( ( ($arg | describe ) == "string" ) and ( $arg | str index-of "{" | $in == 0 ) ) {
        let a = ( $arg | from json | (values)|  escape-string  | str join ' ' )
        $a
    } else {
        let a = ( $arg |  values |  flatten | escape-string | str replace -r '^' '"'   | str replace -r  '$' '"' | str join " " ) #  str replace -r '^"' '' | str replace -r  '"$' '' | 
        $a
    }
}

def escape-string [] {
  let $input = $in
  if ( ( $input | describe ) == "string" ) {
    $input
    | str replace --all '"' '\"' | str replace -r '^' '"'   | str replace -r  '$' '"'
  } else {
    $input
  }
  
}