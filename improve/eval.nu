# Scores an agent against a task file, evals/<agent>.json:
#
#   {
#     "token_cap": 20000,        tokens per task at which the cost part of utility reaches 0
#     "time_cap_sec": 120,       seconds per task at which the time part reaches 0 (also the timeout)
#     "tasks": [
#       { "id": "t1", "query": "...", "expect": { "contains": ["..."] } },
#       { "id": "t2", "query": "...", "expect": { "regex": "..." }, "split": "holdout" }
#     ]
#   }
#
# `expect` may combine contains / not_contains (lists, case-insensitive),
# regex and equals; a task passes when all of them hold. Tasks are
# "train" unless marked "holdout". The improving agent is shown the
# failing train tasks only; holdout tasks check that a change generalizes.

const W_SCORE = 0.5
const W_COST = 0.25
const W_TIME = 0.25

export def load-evals [agent: string] {
    let path = $"evals/($agent).json"
    if not ($path | path exists) {
        error make { msg: $"No task file ($path). Create it to evaluate or improve '($agent)' -- see improve/README.md." }
    }
    let spec = (open $path)
    {
        token_cap: ($spec.token_cap? | default 20000)
        time_cap_sec: ($spec.time_cap_sec? | default 120)
        tasks: ($spec.tasks | each {|t| $t | upsert split ($t.split? | default "train") })
    }
}

def check-answer [answer: string, expect: record] {
    let low = ($answer | str lowercase)
    mut failed = []
    for s in ($expect.contains? | default []) {
        if not ($low | str contains ($s | str lowercase)) { $failed = ($failed | append $"missing '($s)'") }
    }
    for s in ($expect.not_contains? | default []) {
        if ($low | str contains ($s | str lowercase)) { $failed = ($failed | append $"contains forbidden '($s)'") }
    }
    if ($expect.regex? != null) and ($answer !~ $expect.regex) {
        $failed = ($failed | append $"does not match /($expect.regex)/")
    }
    if ($expect.equals? != null) and (($answer | str trim) != ($expect.equals | str trim)) {
        $failed = ($failed | append $"is not exactly '($expect.equals)'")
    }
    $failed
}

export def describe-expect [expect: record] {
    [
        (if ($expect.contains? != null) { $"must contain: ($expect.contains | to json -r)" })
        (if ($expect.not_contains? != null) { $"must not contain: ($expect.not_contains | to json -r)" })
        (if ($expect.regex? != null) { $"must match the regex: ($expect.regex)" })
        (if ($expect.equals? != null) { $"must be exactly: ($expect.equals)" })
    ] | compact | str join "; "
}

def log-files [] {
    if not ("logs" | path exists) { return [] }
    ls logs | where type == "file" | get name | where {|n| ($n | path basename) =~ '^\d+-' }
}

# Tokens used and the steps taken, read from the per-call response files
# agent/internal.nu's `execute` saved during one task.
def read-calls [files: list] {
    let calls = ($files | sort-by {|f| $f | path basename | split row "-" | first | into int } | each {|f| try { open --raw $f | from json } catch { null } } | compact)
    let tokens = ($calls | each {|c|
        let u = ($c.usage? | default {})
        if ($u.total_tokens? != null) {
            $u.total_tokens
        } else {
            ($c.prompt_eval_count? | default 0) + ($c.eval_count? | default 0)
        }
    } | math sum)
    let trace = ($calls | each {|c|
        let m = ($c.message? | default {})
        let tool_calls = ($m.tool_calls? | default [])
        if ($tool_calls | is-not-empty) {
            $tool_calls | each {|tc|
                let args = ($tc.function.arguments | if ($in | describe) == "string" { $in } else { $in | to json -r })
                $"called ($tc.function.name) with ($args | str substring 0..<300)"
            }
        } else {
            [ $"said: ($m.content? | default '' | into string | str substring 0..<300)" ]
        }
    } | flatten)
    { tokens: ($tokens | default 0), calls: ($calls | length), trace: $trace }
}

def run-task [agent: string, task: record, time_cap_sec: int] {
    let before = (log-files)
    let start = (date now)
    let has_timeout = (which timeout | is-not-empty)
    let r = (with-env { EVAL_AGENT: $agent, EVAL_QUERY: $task.query, SELF_IMPROVE_DEPTH: "1" } {
        let code = 'use agent/agents.nu [run_named]; run_named $env.EVAL_AGENT $env.EVAL_QUERY'
        if $has_timeout {
            ^timeout $time_cap_sec $nu.current-exe --no-config-file -c $code | complete
        } else {
            ^$nu.current-exe --no-config-file -c $code | complete
        }
    })
    let seconds = (((date now) - $start) / 1sec)
    let after = (log-files)
    let calls = (read-calls ($after | where {|f| $f not-in $before }))
    let answer = ($r.stdout | str trim)
    let error = if $r.exit_code == 124 {
        $"timed out after ($time_cap_sec)s"
    } else if $r.exit_code != 0 {
        $r.stderr | ansi strip | str trim | str substring 0..<1500
    } else {
        null
    }
    let failed = if $error != null { ["the agent run failed"] } else { check-answer $answer $task.expect }
    {
        id: $task.id
        split: $task.split
        pass: ($failed | is-empty)
        why: ($failed | str join "; ")
        seconds: ($seconds | math round --precision 1)
        tokens: $calls.tokens
        model_calls: $calls.calls
        answer: $answer
        trace: $calls.trace
        error: $error
    }
}

def clamp01 [x: float] {
    [0.0, ([1.0, $x] | math min)] | math max
}

# Score in [0,1], and a utility that also rewards using fewer tokens and
# less time (the weighting used by SICA, arXiv 2504.15228).
def summarize [results: list, token_cap: int, time_cap_sec: int] {
    if ($results | is-empty) {
        return { n: 0, passed: 0, score: null, utility: null, tokens: 0, seconds: 0 }
    }
    let n = ($results | length)
    let passed = ($results | where pass | length)
    let score = ($passed / $n)
    let tokens = ($results | get tokens | math avg)
    let seconds = ($results | get seconds | math avg)
    let utility = ($W_SCORE * $score) + ($W_COST * (1 - (clamp01 ($tokens / $token_cap)))) + ($W_TIME * (1 - (clamp01 ($seconds / $time_cap_sec))))
    {
        n: $n
        passed: $passed
        score: ($score | math round --precision 3)
        utility: ($utility | math round --precision 4)
        tokens: ($tokens | math round)
        seconds: ($seconds | math round --precision 1)
    }
}

export def run-eval [agent: string, --quiet] {
    let spec = (load-evals $agent)
    mkdir logs
    let results = ($spec.tasks | each {|t|
        let r = (run-task $agent $t $spec.time_cap_sec)
        if not $quiet {
            print $"  (if $r.pass { 'PASS' } else { 'FAIL' })  ($r.id) [($r.split)]  ($r.seconds)s  ($r.tokens) tokens(if $r.pass { '' } else { $'  -- ($r.why)' })"
        }
        $r
    })
    {
        agent: $agent
        tasks: $results
        train: (summarize ($results | where split == "train") $spec.token_cap $spec.time_cap_sec)
        holdout: (summarize ($results | where split == "holdout") $spec.token_cap $spec.time_cap_sec)
    }
}
