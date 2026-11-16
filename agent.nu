# Nushell Agents -- entry points.
#
#   nu agent.nu "who contributes to couchbase-shell?" --agent general_oai
#   use agent.nu *; "some text" | agent-ask "summarize this" --agent writer
#
# Agents come from a manifest (agents.json by default; --manifest or
# $env.AGENTS_FILE to use another). `agent-list` shows what is there.
use agent/registry.nu [get-agent, list-agents]
use agent/loop.nu [run-agent]
use agent/journal.nu [export-journal, list-journals, recover-journals]

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
    --sinks (-s): string       # event sinks, e.g. "jsonl,console,otel" (default: $env.AGENT_SINKS)
] {
    let piped = $in
    # (not `default (default-agent ...)`: that would evaluate the fallback, and fail, even when an agent was given)
    let name = (if $agent != null { $agent } else { default-agent $manifest })
    let prompt = (if $piped == null { $query } else { $"($query) ($piped)" })

    # Replay journals a crashed (or collector-less) earlier run left behind.
    if ($env.AGENT_RECOVER? | default "" | str lowercase) in ["true" "1" "yes"] {
        let min_age = ($env.AGENT_RECOVER_MIN_AGE? | default "10min" | into duration)
        for r in (recover-journals $min_age) {
            print --stderr $"recovered ($r.journal): ($r.exported_spans) span\(s\) exported, ($r.incomplete_runs) incomplete run\(s\)"
        }
    }

    let sink_list = (if $sinks == null { null } else { $sinks | split row "," | each {|x| $x | str trim } | where {|x| $x | is-not-empty } })
    let result = (get-agent $name --manifest $manifest | run-agent $prompt --sinks $sink_list)
    if $full { return $result }

    match $result.status {
        "error" => { error make { msg: $"Agent '($name)' failed: ($result.error)" } }
        "truncated" => { print --stderr $"warning: agent '($name)' hit its output limit; the answer is cut off" }
        "max_turns" => { print --stderr $"warning: agent '($name)' ran out of iterations" }
        _ => {}
    }
    $result.answer
}

# Replay event journals to the OTel collector. With a path, that journal; without
# one, every journal in $env.AGENT_LOG_DIR (default logs/). Runs a crashed
# process left unfinished are exported with their open spans closed as
# incomplete, and spans already exported are skipped, so this is safe to repeat.
export def agent-export [journal?: string] {
    if $journal != null {
        [(export-journal ($journal | path expand))]
    } else {
        list-journals | each {|j| export-journal $j.path }
    }
}

def main [
    query: string
    --agent (-a): string
    --manifest (-m): string
    --full (-f)
    --sinks (-s): string
] {
    agent-ask $query --agent $agent --manifest $manifest --full=$full --sinks $sinks
}
