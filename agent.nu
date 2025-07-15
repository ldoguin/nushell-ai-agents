# Agent
use agent/agents.nu [ run_agent, agent ]
use common/utils.nu *

def think_code [$query] {
    init_logger
    "## Calling think_code" | log
    $query | log

    let all_agents = open agents.json
    mut agent = agent $all_agents.cbes_oai

    let answer = ( $agent | run_agent $query )
    $answer
}



def run [$query] {
    let s = $in
    init_logger
    "## Calling run" | log
    let all_agents = open agents.json
    mut agent = agent $all_agents.cbes_oai
    mut agentPrompt = "";
    if ( $s != null ) {
        $agentPrompt = ( [$query, " ", $s] | str join )
    } else {
        $agentPrompt = $query
    }
    let answer = $agent | run_agent $agentPrompt
    $answer
}


def agent_run [agent_name, query] {
    let s = $in
    init_logger
    "## Calling run" | log
    let all_agents = open agents.json
    mut agent = agent ( $all_agents | get $agent_name )
    mut agentPrompt = "";
    if ( $s != null ) {
        $agentPrompt = ( [$query, " ", $s] | str join )
    } else {
        $agentPrompt = $query
    }
    let answer = $agent | run_agent $agentPrompt
    $answer
}

def agent_as_tools [query] {
    
    let s = $in
    init_logger
    "## Calling run" | log
    mut agent = agent {
        "runtime" : "openai",
        "model":"gpt-4o-mini",
        "prompt":"agent_as_tools.txt",
        "model_tools":"agent_as_tools.json",
        "tool_functions":"functions.nu",
        "description":"An agent calling other agents as tools",
        "options" : {
            "stream": false,
            "temperature": 0
            }
    }
    mut agentPrompt = "";
    if ( $s != null ) {
        $agentPrompt = ( [$query, " ", $s] | str join )
    } else {
        $agentPrompt = $query
    }
    let answer = $agent | run_agent $agentPrompt
    $answer
}


def function_from_json [jsonPath] {
    let agents = open $jsonPath
    let tuples = $agents | transpose k v | each { |a|
        let tool =  {
            "type": "function",
            "function": {
            "name": $a.k,
            "description": $a.v.description,
            "parameters": {
                "type": "object",
                "properties": {
                "query": {
                    "description": "the question you want to ask the agent",
                    "type": "string"
                }
                },
                "required": [
                "query"
                ]
            }
            }
        }
        let function = $"  def ($a.k) [query] {\n    let result_tool = \( cbsh -c \( $\" source agent.nu;  agent_run \"($a.k)\" \"\($query\)\" \"  \)  \) | complete \n    if \( $result_tool.exit_code == 0 \) { \n      return $result_tool.stdout \n    } else {\n      print $result_tool.stderr \n     return $result_tool \n  } \n}"
        [$tool, $function]
    }
    mut  tools = []
    mut  functions  = []
    for t in $tuples {
        $tools = $tools | append $t.0
        $functions = $functions | append $t.1
    }

    $functions | to text | save -f functions.nu
    $tools | to json | save -f agent_as_tools.json


}

