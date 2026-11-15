# Nushell Agents -- entry points.
#
#   nu agent.nu "who contributes to couchbase-shell?" --agent general_oai
#   use agent.nu *; "some text" | agent-ask "summarize this" --agent writer
#
# Agents come from a manifest (agents.json by default; --manifest or
# $env.AGENTS_FILE to use another). `agent-list` shows what is there.
use agent/registry.nu [get-agent, list-agents]
use agent/loop.nu [run-agent]

# The agent to use when none is named: $env.AGENT_NAME, else the manifest's
# only agent.
def default-agent [manifest?: string] {
    let named = ($env.AGENT_NAME? | default "")
    if ($named | is-not-empty) { return $named }
    let all = (list-agents --manifest $manifest | get name)
    if ($all | length) == 1 { return ($all | first) }
    error make { msg: $"Choose an agent with --agent or $env.AGENT_NAME. Available: ($all | str join ', ')" }
}

# The agents in the manifest.
export def agent-list [--manifest (-m): string] {
    list-agents --manifest $manifest
}

# Ask an agent a question. Text piped in is appended to the question. Returns
# the answer; with --full, returns the whole result record (status, answer,
# messages, usage, ...) and never raises for a failed run.
export def agent-ask [
    query: string
    --agent (-a): string       # which agent (default: $env.AGENT_NAME, else the manifest's only one)
    --manifest (-m): string    # agents.json to use
    --full (-f)                # return the full result record
] {
    let piped = $in
    # (not `default (default-agent ...)`: that would evaluate the fallback, and fail, even when an agent was given)
    let name = (if $agent != null { $agent } else { default-agent $manifest })
    let prompt = (if $piped == null { $query } else { $"($query) ($piped)" })

    let result = (get-agent $name --manifest $manifest | run-agent $prompt)
    if $full { return $result }

    match $result.status {
        "error" => { error make { msg: $"Agent '($name)' failed: ($result.error)" } }
        "truncated" => { print --stderr $"warning: agent '($name)' hit its output limit; the answer is cut off" }
        "max_turns" => { print --stderr $"warning: agent '($name)' ran out of iterations" }
        _ => {}
    }
    $result.answer
}

def main [
    query: string
    --agent (-a): string
    --manifest (-m): string
    --full (-f)
] {
    agent-ask $query --agent $agent --manifest $manifest --full=$full
}
