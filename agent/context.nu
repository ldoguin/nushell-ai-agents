# Keeping a run inside its limits: budgets and context size. Pure functions
# over a run's usage and messages; the loop (agent/loop.nu) decides when to call
# them.
#
# BUDGETS. An agent may set `max_total_tokens` and/or `max_cost_usd`. They bound
# one run, sub-agents included: a sub-agent can use at most what is left of its
# caller's budget. They are checked before each model call, so a run stops
# (status `budget_exceeded`) as soon as it has used up its allowance; they cannot
# stop a single call that is already under way. Cost needs a provider that
# reports it (a LiteLLM proxy does; api.anthropic.com does not), otherwise only
# the token budget can be enforced.
#
# COMPACTION. `context: { max_prompt_tokens, keep_rounds, min_result_chars }`.
# When the conversation grows past max_prompt_tokens, the output of old tool
# calls -- usually the bulk of it -- is replaced by a short marker. Everything
# else is kept: the system prompt, user messages, the model's own messages and
# its tool calls, and the results of the last `keep_rounds` tool rounds. It is
# deterministic and makes no model call, so it is free, repeatable, and cannot
# lose what the model itself wrote. (Summarising with a model is a possible
# later step; it is not here.)

const ELIDED_PREFIX = "[output elided to save context:"

# The effective limits of a run: the tighter of the agent's own and those
# inherited from its caller. null means unlimited.
export def effective-limits [own: record, inherited: record] {
    let tighter = {|a, b|
        if $a == null { $b } else if $b == null { $a } else if $a < $b { $a } else { $b }
    }
    {
        max_total_tokens: (do $tighter ($own | get -o max_total_tokens | default null) ($inherited | get -o max_total_tokens | default null))
        max_cost_usd: (do $tighter ($own | get -o max_cost_usd | default null) ($inherited | get -o max_cost_usd | default null))
    }
}

# Which limit `usage` has reached, as { limit, used, max }, or null.
export def over-budget [usage: record, limits: record] {
    let max_tokens = ($limits | get -o max_total_tokens | default null)
    if $max_tokens != null and $usage.total_tokens >= $max_tokens {
        return { limit: "max_total_tokens", used: $usage.total_tokens, max: $max_tokens }
    }
    let max_cost = ($limits | get -o max_cost_usd | default null)
    let spent = ($usage | get -o cost_usd | default null)
    if $max_cost != null and $spent != null and $spent >= $max_cost {
        return { limit: "max_cost_usd", used: $spent, max: $max_cost }
    }
    null
}

# What is left of `limits` after `usage`, as limits for a sub-agent. Never negative.
export def remaining-limits [usage: record, limits: record] {
    let max_tokens = ($limits | get -o max_total_tokens | default null)
    let max_cost = ($limits | get -o max_cost_usd | default null)
    let spent = ($usage | get -o cost_usd | default null)
    {
        max_total_tokens: (if $max_tokens == null { null } else { [($max_tokens - $usage.total_tokens) 0] | math max })
        max_cost_usd: (if $max_cost == null { null } else { [($max_cost - ($spent | default 0.0)) 0.0] | math max })
    }
}

# A rough token count: about four characters per token. Only used to decide
# when to compact, so it errs on the side of being cheap, not exact.
export def estimate-tokens [messages: list] {
    let chars = ($messages | each {|m|
        let content = ($m | get -o content | default "")
        let calls = ($m | get -o tool_calls | default [] | each {|c| $c.function.name + ($c.function.arguments | if ($in | describe) == "string" { $in } else { to json --raw }) } | str join "")
        (if ($content | describe) == "string" { $content | str length } else { $content | to json --raw | str length }) + ($calls | str length)
    } | reduce --fold 0 {|n, acc| $acc + $n })
    ($chars / 4) | math ceil | into int
}

# Replace old tool outputs with a marker. A "round" is one assistant message
# carrying tool calls plus the tool messages answering it; the last `keep_rounds`
# rounds are left alone, and so are outputs shorter than `min_chars` (eliding
# them would save nothing). Returns { messages, elided, chars_saved }.
export def compact-messages [messages: list, keep_rounds: int, min_chars: int] {
    let starts = ($messages | enumerate | where {|m| $m.item.role == "assistant" and ($m.item | get -o tool_calls | default [] | is-not-empty) } | get index)
    # index of the first message that must be kept: the start of the last
    # `keep_rounds` rounds (past the end when keeping none, 0 when keeping all)
    let protect_from = (if $keep_rounds == 0 {
        $messages | length
    } else if ($starts | length) <= $keep_rounds {
        0
    } else {
        $starts | get (($starts | length) - $keep_rounds)
    })

    let results = ($messages | enumerate | each {|m|
        let item = $m.item
        let content = ($item | get -o content | default "")
        let marker = (if ($content | describe) == "string" { $"($ELIDED_PREFIX) ($content | str length) characters]" } else { "" })
        let saved = (if ($content | describe) == "string" { ($content | str length) - ($marker | str length) } else { 0 })
        let eligible = ($m.index < $protect_from) and $item.role == "tool" and ($content | describe) == "string" and (not ($content | str starts-with $ELIDED_PREFIX)) and (($content | str length) > $min_chars) and $saved > 0
        if $eligible {
            { message: ($item | upsert content $marker), saved: $saved }
        } else {
            { message: $item, saved: 0 }
        }
    })
    {
        messages: ($results | get message)
        elided: ($results | where saved > 0 | length)
        chars_saved: ($results | get saved | reduce --fold 0 {|n, acc| $acc + $n })
    }
}
