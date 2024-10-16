# Agent
use agent/agents.nu [openai-mini-o_agent, run_agent ]

def think_code [$query] {
    print "## Calling think_code"
    print $query

    mut agent = openai-mini-o_agent
    let answer = ( $agent | run_agent $query )
    $answer
}

def run [$query] {
    print "## Calling run"
    mut agent = openai-mini-o_agent
    let answer = $agent | run_agent $query 
    $answer
}
