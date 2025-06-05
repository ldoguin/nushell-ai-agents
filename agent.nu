# Agent
use agent/agents.nu [openai-mini-o_agent, openai-cbes-mini-o_agent, run_agent ]
use tools/tools.nu [tool_library, cbsh_tool_library]
use common/utils.nu *

def think_code [$query] {
    init_logger
    "## Calling think_code" | log
    $query | log

    let model_tools = tool_library
    mut agent = openai-mini-o_agent $model_tools

    let answer = ( $agent | run_agent $query )
    $answer
}

def run [$query] {
    let s = $in
    init_logger
    "## Calling run" | log
    let to = open cbes-tool.json
    let model_tools = $to
    mut agent = openai-cbes-mini-o_agent $model_tools
    mut agentPrompt = "";
    if ( $s != null ) {
        $agentPrompt = ( [$query, " ", $s] | str join )
    } else {
        $agentPrompt = $query
    }
    print $agentPrompt
    let answer = $agent | run_agent $agentPrompt
    $answer
}
