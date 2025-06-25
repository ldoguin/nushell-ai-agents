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
