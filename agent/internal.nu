use ../common/utils.nu *
use ../common/otel.nu *
use ../tools/runtime.nu *

# Wraps one run-tool invocation with an "execute_tool" span, per
# OpenTelemetry's GenAI semantic conventions (gen_ai.operation.name =
# execute_tool, span name `execute_tool <tool name>`, gen_ai.tool.name/
# gen_ai.tool.call.id attributes). Arguments/results are only recorded as
# span attributes when otel-capture-tool-content is enabled -- the spec
# itself flags both gen_ai.tool.call.arguments and gen_ai.tool.call.result
# as "may contain sensitive information", opt-in attributes, not
# recommended/required ones. `args_json` is the model's raw arguments.
# Returns the text to give back to the model. run-tool never raises: a failed
# tool is a result, so the span is marked ERROR but the loop carries on and
# the model gets to see the error and recover.
def execute-tool-with-span [name: string, call_id: string, args_json: string, tools: record, parent: record, tool: record] {
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
    let result = (run-tool $tools $tool)
    let text = (tool-result-text $result)
    if $result.ok {
        let end_attrs = (if (otel-capture-tool-content) { { "gen_ai.tool.call.result": $text } } else { {} })
        otel-end-span $span $end_attrs
        otel-record-counter "agent.tool.call.count" "{call}" 1.0 { "gen_ai.tool.name": $name, "status": "ok" }
    } else {
        otel-end-span $span { "error.type": "tool_error" } $result.error [(otel-exception-event "tool_error" $result.error)]
        otel-record-counter "agent.tool.call.count" "{call}" 1.0 { "gen_ai.tool.name": $name, "status": "error" }
    }
    $text
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
            let toolresponse = (execute-tool-with-span $tc.item.function.name $call_id $tc.item.function.arguments ($agent | get -o tools | default (tool-context {} [])) $tool_parent $tc.item.function)
            mut tool_call_back_msg = {"role": "tool", "name" : $tc.item.function.name , "content": $toolresponse};
            if ($tc.item | column_exist "id") {
                $tool_call_back_msg  = ( $tool_call_back_msg | merge {"id" : $tc.item.id, "tool_call_id" : $tc.item.id } )
            }
            $magent.messages = ($magent.messages | append  $tool_call_back_msg )
            #$magent.messages = ($magent.messages | append  {"role": "user", "content": $"Observation: ($toolresponse)"} )
        }
    } else if ($msg.role == "assistant" ) {
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

    # One line per model call for whoever wants to total up a run's cost: set
    # AGENT_COST_FILE to a path and every call appends a JSON record to it
    # (cost fields are null unless the endpoint is a proxy that reports
    # them, see proxy-cost in model.nu). Best effort: a failure here must
    # never fail the call itself.
    let cost_file = ($env.AGENT_COST_FILE? | default "")
    if ($cost_file | is-not-empty) {
        try {
            let cost = ($result | get -o cost | default {})
            ({
                agent: ($agent | get -o agent_name | default "")
                model: $otel_model
                input_tokens: $input_tokens
                output_tokens: $output_tokens
                cost_usd: ($cost | get -o cost_usd | default null)
                key_spend: ($cost | get -o key_spend | default null)
                key_max_budget: ($cost | get -o key_max_budget | default null)
            } | to json --raw) + "\n" | save --append $cost_file
        } catch {|e| print $"::warning::Could not record this call's cost: ($e.msg)" }
    }

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