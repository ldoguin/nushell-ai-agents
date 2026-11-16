# Budgets and compaction: the pure functions, compaction inside the loop, config.
use std/assert
use lib.nu *
use ../agent/agents.nu [agent]
use ../agent/loop.nu [run-agent]
use ../agent/config.nu [resolve-config]
use ../agent/journal.nu [read-journal]
use ../agent/session.nu [load-session]
use ../agent/context.nu [effective-limits, over-budget, remaining-limits, estimate-tokens, compact-messages]

def usage [tokens: int, cost: any = null] {
    { prompt_tokens: 0, completion_tokens: 0, total_tokens: $tokens, calls: 1, cost_usd: $cost }
}

# ---------------------------------------------------------------- budgets

export def test-the-tighter-limit-wins [] {
    assert equal (effective-limits { max_total_tokens: 100, max_cost_usd: null } { max_total_tokens: 50, max_cost_usd: 2.0 }) { max_total_tokens: 50, max_cost_usd: 2.0 }
    assert equal (effective-limits { max_total_tokens: 100, max_cost_usd: 1.0 } { max_total_tokens: 500, max_cost_usd: 2.0 }) { max_total_tokens: 100, max_cost_usd: 1.0 }
    assert equal (effective-limits { max_total_tokens: null, max_cost_usd: null } {}) { max_total_tokens: null, max_cost_usd: null }
}

export def test-over-budget-reports-which-limit-was-reached [] {
    assert equal (over-budget (usage 99) { max_total_tokens: 100 }) null
    assert equal (over-budget (usage 100) { max_total_tokens: 100 }) { limit: "max_total_tokens", used: 100, max: 100 }
    assert equal (over-budget (usage 1 0.5) { max_cost_usd: 0.5 }) { limit: "max_cost_usd", used: 0.5, max: 0.5 }
    assert equal (over-budget (usage 1 0.4) { max_cost_usd: 0.5 }) null
    assert equal (over-budget (usage 1000000 99.0) { max_total_tokens: null, max_cost_usd: null }) null "no limits, no problem"
    assert equal (over-budget (usage 1000000) { max_cost_usd: 0.5 }) null "unknown cost cannot trip a cost limit"
}

export def test-remaining-limits-never-go-negative [] {
    assert equal (remaining-limits (usage 30) { max_total_tokens: 100, max_cost_usd: null }) { max_total_tokens: 70, max_cost_usd: null }
    assert equal (remaining-limits (usage 150) { max_total_tokens: 100 }).max_total_tokens 0
    assert equal (remaining-limits (usage 1 0.25) { max_cost_usd: 1.0 }).max_cost_usd 0.75
    assert equal (remaining-limits (usage 1 5.0) { max_cost_usd: 1.0 }).max_cost_usd 0.0
}

# ------------------------------------------------------------ estimation

export def test-token-estimate-is-about-four-characters-each [] {
    assert equal (estimate-tokens []) 0
    assert equal (estimate-tokens [{ role: "user", content: ("x" | fill --width 400 --character x) }]) 100
    # tool-call arguments count, and non-text content does not crash it
    let with_calls = [{ role: "assistant", content: null, tool_calls: [{ id: "c", type: "function", function: { name: "tool", arguments: ("a" | fill --width 96 --character a) } }] }]
    assert equal (estimate-tokens $with_calls) 25
    assert ((estimate-tokens [{ role: "user", content: [{ type: "text", text: "hello" }] }]) > 0)
}

# ------------------------------------------------------------- compaction

def round [n: int, size: int] {
    [
        { role: "assistant", content: null, tool_calls: [{ id: $"c($n)", type: "function", function: { name: "t", arguments: "{}" } }] }
        { role: "tool", name: "t", content: ("x" | fill --width $size --character x), tool_call_id: $"c($n)" }
    ]
}

export def test-compaction-elides-old-tool-output-and-nothing-else [] {
    let messages = ([{ role: "system", content: "sys" } { role: "user", content: "q" }] | append (round 1 1000) | append (round 2 1000) | append (round 3 1000))
    let r = (compact-messages $messages 1 100)
    assert equal $r.elided 2
    let tools = ($r.messages | where role == "tool")
    assert equal ($tools | get content | each { $in | str starts-with "[output elided to save context:" }) [true true false]
    assert equal $tools.0.content "[output elided to save context: 1000 characters]"
    assert equal $tools.2.content ("x" | fill --width 1000 --character x) "the latest round is untouched"
    # everything but those two contents is identical, including call ids and tool names
    assert equal ($r.messages | where role != "tool") ($messages | where role != "tool")
    assert equal ($r.messages | where role == "tool" | select name tool_call_id) [{ name: "t", tool_call_id: "c1" } { name: "t", tool_call_id: "c2" } { name: "t", tool_call_id: "c3" }]
    assert equal $r.chars_saved (2 * (1000 - ("[output elided to save context: 1000 characters]" | str length)))
}

export def test-compaction-keeps-the-requested-number-of-rounds [] {
    let messages = ((round 1 500) | append (round 2 500) | append (round 3 500))
    assert equal (compact-messages $messages 0 100 | get elided) 3
    assert equal (compact-messages $messages 2 100 | get elided) 1
    assert equal (compact-messages $messages 3 100 | get elided) 0
    assert equal (compact-messages $messages 9 100 | get messages) $messages
}

export def test-compaction-leaves-short-outputs-and-is-idempotent [] {
    let messages = ((round 1 50) | append (round 2 1000) | append (round 3 1000))
    let once = (compact-messages $messages 1 100)
    assert equal $once.elided 1 "the 50-character output is not worth eliding"
    assert equal ($once.messages | where role == "tool" | first | get content | str length) 50
    let twice = (compact-messages $once.messages 1 100)
    assert equal $twice.elided 0
    assert equal $twice.messages $once.messages
    # a marker is never longer than what it replaces, even with min_chars 0
    assert equal (compact-messages ((round 1 10) | append (round 2 10)) 1 0 | get elided) 0
}

# ------------------------------------------------- compaction in the loop

def tool-call [name: string, arguments: record = {}] {
    { tool_calls: [{ name: $name, arguments: $arguments }] }
}

export def test-the-loop-compacts-when-the-conversation-grows-and-says-so [] {
    let t = (make-tools)
    let big = (1..300 | each { "x" } | str join)
    let cfg = ((mock-agent-config [(tool-call echo_tool { text: $big }) (tool-call echo_tool { text: $big }) (tool-call echo_tool { text: $big }) "done"] $t) | merge { context: { max_prompt_tokens: 100, keep_rounds: 1, min_result_chars: 50 } })
    let r = (with-env { AGENT_SINKS: "jsonl", AGENT_LOG_DIR: ($t.dir | path join logs), AGENT_SESSION_DIR: ($t.dir | path join sessions) } {
        agent $cfg --name tester | run-agent "go" --session s1
    })
    assert equal $r.status "done"
    let results = ($r.messages | where role == "tool" | get content)
    assert equal ($results | each { $in | str starts-with "[output elided" }) [true true false] "old outputs elided, the latest intact"
    assert equal ($results | last) $"echo:($big)"

    # it is reported as events, so a journal shows when and how much
    let events = (read-journal $r.journal | where type == "context.compacted")
    assert equal ($events | get elided) [1 1]
    assert ($events.0.chars_saved > 200)
    assert equal $events.0.max_prompt_tokens 100

    # and the smaller conversation is what a resumed session carries forward
    let saved = (with-env { AGENT_SESSION_DIR: ($t.dir | path join sessions) } { load-session s1 })
    assert equal ($saved.messages | where role == "tool" | get content | first | str starts-with "[output elided") true
}

export def test-compaction-does-nothing-under-the-limit [] {
    let t = (make-tools)
    let cfg = ((mock-agent-config [(tool-call echo_tool { text: "small" }) "done"] $t) | merge { context: { max_prompt_tokens: 100000 } })
    let r = (agent $cfg --name tester | run-agent "go")
    assert equal ($r.messages | where role == "tool" | get content) ["echo:small"]
}

# ----------------------------------------------------------------- config

def cfg-error [config: record] {
    error-of { resolve-config ({ runtime: "mock" } | merge $config) "/tmp" "agent 'a'" }
}

export def test-budget-and-context-settings-are-validated [] {
    assert ((cfg-error { max_total_tokens: 0 }) | str contains "'max_total_tokens' must be a whole number >= 1")
    assert ((cfg-error { max_total_tokens: "lots" }) | str contains "'max_total_tokens'")
    assert ((cfg-error { max_cost_usd: -1 }) | str contains "'max_cost_usd' must be a positive number")
    assert ((cfg-error { context: "big" }) | str contains "'context' must be an object")
    assert ((cfg-error { context: { keep_rounds: 2 } }) | str contains "'context.max_prompt_tokens' is required")
    assert ((cfg-error { context: { max_prompt_tokens: 100, keep: 1 } }) | str contains "unknown key(s): keep")
    assert ((cfg-error { context: { max_prompt_tokens: 100, keep_rounds: -1 } }) | str contains "'context.keep_rounds' must be a whole number >= 0")
    assert equal (cfg-error { max_total_tokens: 1000, max_cost_usd: 0.5, context: { max_prompt_tokens: 100 } }) null
}

export def test-context-defaults-are-filled-in [] {
    let r = (resolve-config { runtime: "mock", context: { max_prompt_tokens: 5000 } } "/tmp" "a")
    assert equal $r.context { keep_rounds: 2, min_result_chars: 500, max_prompt_tokens: 5000 }
    assert equal (resolve-config { runtime: "mock" } "/tmp" "a" | get context) null
    let a = (agent { runtime: "mock", max_total_tokens: 50, context: { max_prompt_tokens: 10 } })
    assert equal $a.budget { max_total_tokens: 50, max_cost_usd: null }
    assert equal $a.context.max_prompt_tokens 10
}
