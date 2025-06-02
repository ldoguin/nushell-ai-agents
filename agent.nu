# Agent
use agent/agents.nu [openai-mini-o_agent, run_agent ]
use tools/tools.nu [tool_library, cbsh_tool_library]

def think_code [$query] {
    print "## Calling think_code"
    print $query

    let model_tools = tool_library
    mut agent = openai-mini-o_agent $model_tools

    let answer = ( $agent | run_agent $query )
    $answer
}

def run [$query] {
    print "## Calling run"
    let model_tools = cbsh_tool_library
    mut agent = openai-mini-o_agent $model_tools
    let answer = $agent | run_agent $query 
    $answer
}
