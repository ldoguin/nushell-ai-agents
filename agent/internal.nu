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
        otel-record-counter "agent.tool.call.count" "{call}" 1.0 { "gen_ai.tool.name": $name, "status": "ok" }
        $result
    } catch {|e|
        otel-end-span $span { "error.type": "_OTHER" } $e.msg [(otel-exception-event "_OTHER" $e.msg)]
        otel-record-counter "agent.tool.call.count" "{call}" 1.0 { "gen_ai.tool.name": $name, "status": "error" }
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
    # Captured once, up front: $in inside a nested `try` block does not
    # reliably resolve back to this function's own $in after it's already
    # been read once via pipe (a real Nushell quirk, confirmed with an
    # isolated repro) -- so model_call/messages must be read into plain
    # variables here rather than accessed as $in.model_call/$in.messages
    # inside the try below.
    let agent = $in
    # $in.otel_parent/otel_runtime/otel_model are optional fields riding
    # along on the agent record (set by run-pipeline-agent/run_agent), not
    # part of model_call's own captured state -- reading them here needs no
    # signature changes anywhere in the call chain.
    let otel_parent = ($agent | get -o otel_parent | default {})
    let otel_runtime = ($agent | get -o otel_runtime | default "unknown")
    let otel_model = ($agent | get -o otel_model | default "unknown")
    let otel_provider = (otel-provider-name $otel_runtime)
    let start_ns = (now-ns)
    let span = (otel-start-span "gen_ai.chat" $otel_parent { "gen_ai.operation.name": "chat", "gen_ai.provider.name": $otel_provider, "gen_ai.request.model": $otel_model })

    mut result = (try {
        do $agent.model_call $agent.messages
    } catch {|e|
        otel-end-span $span { "error.type": "_OTHER" } $e.msg [(otel-exception-event "_OTHER" $e.msg)]
        error make { msg: $e.msg }
    })
    # Only get the first choice when model propose different choices
    if ( $result | column_exist "choices" ) {
        let choice0 = $result.choices.0
        let message = ( $choice0.message | insert finish_reason  $choice0.finish_reason )
        $result = ( $result | insert message $message )
    }

    let usage = ($result | get -o usage | default {})
    let input_tokens = ($usage | get -o prompt_tokens | default 0)
    let output_tokens = ($usage | get -o completion_tokens | default 0)
    let retry_count = ($result | get -o retry_attempts | default 1)
    let duration_s = (((now-ns) - $start_ns) | into float) / 1_000_000_000.0

    let metric_attrs = { "gen_ai.operation.name": "chat", "gen_ai.provider.name": $otel_provider, "gen_ai.request.model": $otel_model }
    otel-record-histogram "gen_ai.client.token.usage" "{token}" ($input_tokens | into float) ($metric_attrs | insert "gen_ai.token.type" "input")
    otel-record-histogram "gen_ai.client.token.usage" "{token}" ($output_tokens | into float) ($metric_attrs | insert "gen_ai.token.type" "output")
    otel-record-histogram "gen_ai.client.operation.duration" "s" $duration_s $metric_attrs

    otel-end-span $span {
        "gen_ai.usage.input_tokens": $input_tokens
        "gen_ai.usage.output_tokens": $output_tokens
        "retry_count": $retry_count
    }

    # Replaces the old per-call file dump (logs/<counter>-<uuid>) -- those
    # files never survived an ephemeral CI runner once the job ended.
    # Sending this as a log record correlated to $span means it lands
    # wherever OTEL_EXPORTER_OTLP_ENDPOINT already points, alongside the
    # gen_ai.chat span it belongs to, instead of a file a human had to
    # match up by timestamp after the fact.
    otel-send-log ($result | to json) { "gen_ai.operation.name": "chat", "gen_ai.provider.name": $otel_provider, "gen_ai.request.model": $otel_model } "info" { trace_id: $span.trace_id, span_id: $span.span_id }
    if ($env.AGENT_LOG? != null and ( $env.AGENT_LOG | into bool ) ) {
        print ($result | to json)
    }
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