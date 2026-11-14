#!/usr/bin/env nu
# Self-improvement loop. Run from the repository root:
#
#   nu improve/improve.nu eval <agent>            score an agent on evals/<agent>.json
#   nu improve/improve.nu run <agent>             let an agent improve <agent>
#   nu improve/improve.nu history <agent>         list the attempts made so far
#
# See improve/README.md for how it works.
use eval.nu *
use scope.nu *

const ARCHIVE_DIR = "improve/archive"

def --wrapped git [...args: string] {
    let r = (^git ...$args | complete)
    if $r.exit_code != 0 {
        error make { msg: $"git ($args | str join ' ') failed: ($r.stderr | str trim)" }
    }
    $r.stdout
}

def changed-paths [] {
    git status --porcelain --untracked-files=all | lines | where {|l| ($l | str trim | is-not-empty) } | each {|l| $l | str substring 3.. }
}

def discard-changes [] {
    git reset --hard --quiet HEAD
    git clean -fd --quiet
}

def archive-path [agent: string] {
    $"($ARCHIVE_DIR)/($agent).jsonl"
}

def load-archive [agent: string] {
    let path = (archive-path $agent)
    if ($path | path exists) {
        open --raw $path | lines | where {|l| ($l | str trim | is-not-empty) } | each {|l| $l | from json }
    } else {
        []
    }
}

def all-agents [] {
    ls **/agents.json | get name | reduce --fold {} {|e, acc| open $e | merge $acc }
}

def agent-files [config: record] {
    let folder = ($config.folder? | default null)
    [
        ($config.prompt? | default (if $folder != null { $"($folder)/prompt.txt" }))
        ($config.model_tools? | default (if $folder != null { $"($folder)/tools.json" }))
        ($config.tool_functions? | default (if $folder != null { $"($folder)/functions.nu" }))
        ($config.memory? | default null)
    ] | compact
}

def fmt-summary [s: record] {
    if $s.n == 0 { "no tasks" } else { $"($s.passed)/($s.n) passed, utility ($s.utility), ($s.tokens) tokens and ($s.seconds)s per task" }
}

# What the improving agent is told: the target, where it fails, and what
# was already tried. Holdout tasks are left out on purpose.
def build-brief [agent: string, config: record, baseline: record, archive: list] {
    let failing = ($baseline.tasks | where split == "train" | where {|t| not $t.pass })
    let passing = ($baseline.tasks | where split == "train" | where pass | get id)
    let queries = (load-evals $agent | get tasks | select id query expect)
    let failing_text = if ($failing | is-empty) {
        "None. Every visible task passes, so look for ways to get the same answers with fewer model calls, fewer tokens or less time."
    } else {
        $failing | each {|t|
            let task = ($queries | where id == $t.id | first)
            [
                $"### Task ($t.id)"
                $"Query: ($task.query)"
                $"Requirement on the answer: (describe-expect $task.expect)"
                $"Result: ($t.why)"
                (if $t.error != null { $"Error:\n($t.error)" })
                $"What the agent did:\n($t.trace | each {|s| $'- ($s)' } | str join "\n")"
                $"Final answer:\n($t.answer | str substring 0..<1500)"
            ] | compact | str join "\n"
        } | str join "\n\n"
    }
    let history = if ($archive | is-empty) {
        "None yet."
    } else {
        $archive | last 6 | each {|a|
            $"- Attempt ($a.attempt): ($a.outcome) -- ($a.reason). Files: ($a.files | str join ', '). The improver's summary: ($a.summary | str substring 0..<300)"
        } | str join "\n"
    }
    [
        $"# Improve the agent `($agent)`"
        ""
        "## Its entry in agents.json"
        ($config | to json)
        ""
        "## Files it is made of"
        (agent-files $config | each {|f| $"- ($f)(if (can-write $f) { '' } else { '  (read-only for you)' })" } | str join "\n")
        ""
        $"## Current results on the visible tasks"
        (fmt-summary $baseline.train)
        $"Passing: (if ($passing | is-empty) { 'none' } else { $passing | str join ', ' })"
        ""
        "## Failing tasks"
        $failing_text
        ""
        "## Earlier attempts"
        $history
    ] | str join "\n"
}

def run-improver [improver: string, brief: string] {
    with-env { IMPROVE_AGENT: $improver, IMPROVE_BRIEF: $brief } {
        ^$nu.current-exe --no-config-file -c 'use agent/agents.nu [run_named]; run_named $env.IMPROVE_AGENT $env.IMPROVE_BRIEF' | complete
    }
}

# Decide whether a candidate replaces the baseline. A candidate must not
# lose correctness on either split, and must gain either correctness or
# at least `min_gain` utility on the train split.
def judge [baseline: record, candidate: record, min_gain: float] {
    let b = $baseline.train
    let c = $candidate.train
    if $c.score < $b.score {
        return { accept: false, reason: $"train score dropped from ($b.score) to ($c.score)" }
    }
    if ($baseline.holdout.n > 0) and ($candidate.holdout.score < $baseline.holdout.score) {
        return { accept: false, reason: $"holdout score dropped from ($baseline.holdout.score) to ($candidate.holdout.score)" }
    }
    if $c.score > $b.score {
        return { accept: true, reason: $"train score rose from ($b.score) to ($c.score)" }
    }
    if ($baseline.holdout.n > 0) and ($candidate.holdout.score > $baseline.holdout.score) {
        return { accept: true, reason: $"holdout score rose from ($baseline.holdout.score) to ($candidate.holdout.score)" }
    }
    if ($c.utility - $b.utility) >= $min_gain {
        return { accept: true, reason: $"same score, utility rose from ($b.utility) to ($c.utility)" }
    }
    { accept: false, reason: $"no gain: score ($c.score), utility ($b.utility) -> ($c.utility)" }
}

def record-attempt [agent: string, entry: record, patch: string] {
    mkdir $"($ARCHIVE_DIR)/($agent)"
    if ($patch | is-not-empty) {
        $patch | save -f $"($ARCHIVE_DIR)/($agent)/($entry.attempt).patch"
    }
    $"($entry | to json -r)\n" | save --append (archive-path $agent)
}

# Score an agent on its task file.
def "main eval" [agent: string] {
    print $"Evaluating ($agent)"
    let result = (run-eval $agent)
    print $"train:   (fmt-summary $result.train)"
    print $"holdout: (fmt-summary $result.holdout)"
}

# List the improvement attempts recorded for an agent.
def "main history" [agent: string] {
    load-archive $agent | each {|a| $a | update reason ($a.reason | lines | first) | update files ($a.files | str join ', ') } | select attempt outcome reason files train_score train_utility holdout_score
}

# Let an agent improve another agent (or itself), one attempt at a time.
# Each attempt is evaluated; it is committed if it helps and reverted if
# it does not. Every attempt is recorded in improve/archive/.
def "main run" [
    agent: string                          # the agent to improve
    --iterations (-n): int = 3             # attempts to make
    --improver: string = "self_improver"   # the agent that makes the changes
    --min-gain: float = 0.01               # utility gain needed when the score is unchanged
    --allow-default-branch                 # commit on main/master instead of refusing
] {
    let agents = (all-agents)
    for name in [$agent $improver] {
        if not ($name in ($agents | columns)) { error make { msg: $"Unknown agent '($name)'." } }
    }
    let branch = (git rev-parse --abbrev-ref HEAD | str trim)
    if ($branch in ["main" "master"]) and (not $allow_default_branch) {
        error make { msg: $"Refusing to commit self-made changes on '($branch)'. Switch to a branch, or pass --allow-default-branch." }
    }
    if (changed-paths | is-not-empty) {
        error make { msg: "The working tree has uncommitted changes. Commit or stash them first: rejected attempts are reverted with git reset and git clean." }
    }
    load-evals $agent | ignore

    print $"Baseline for ($agent)"
    mut baseline: any = (run-eval $agent)
    print $"train:   (fmt-summary $baseline.train)"
    print $"holdout: (fmt-summary $baseline.holdout)"
    discard-changes

    for i in 1..$iterations {
        let archive = (load-archive $agent)
        let attempt = (($archive | length) + 1)
        print $"\nAttempt ($attempt) \(($i) of ($iterations)\): ($improver) is working on ($agent)"
        let config = (all-agents | get $agent)
        let run = (run-improver $improver (build-brief $agent $config $baseline $archive))
        let summary = ($run.stdout | str trim | lines | last 1 | str join "" | str replace -r '^Answer:\s*' '')
        let files = (changed-paths)
        let patch = if ($files | is-empty) { "" } else {
            git add -A
            let p = (git diff --cached HEAD)
            git reset --quiet
            $p
        }

        # Gate 1: the run itself, and where the changes landed.
        let out_of_scope = ($files | where {|f| not (can-write $f) })
        let broken = ($files | where {|f| $f | path exists } | each {|f| check-file $f } | compact)
        let early = if $run.exit_code != 0 {
            $"the improver failed: ($run.stderr | ansi strip | str trim | str substring 0..<300)"
        } else if ($files | is-empty) {
            "the improver changed nothing"
        } else if ($out_of_scope | is-not-empty) {
            $"changed files outside the writable scope: ($out_of_scope | str join ', ')"
        } else if ($broken | is-not-empty) {
            $"left a file that does not parse: ($broken | first | str substring 0..<400)"
        } else {
            null
        }

        # Gate 2: does the agent actually do better?
        mut candidate: any = null
        mut verdict: any = { accept: false, reason: $early }
        if $early == null {
            # Evaluate, then drop anything the evaluated agent wrote and
            # restore exactly the candidate's changes.
            let result = (run-eval $agent)
            discard-changes
            let tmp = (mktemp -t attempt.XXXXXX)
            $patch | save -f --raw $tmp
            git apply --index $tmp
            rm -f $tmp
            $candidate = $result
            $verdict = (judge $baseline $result $min_gain)
        }

        let entry = {
            attempt: $attempt
            date: (date now | format date "%Y-%m-%dT%H:%M:%S%z")
            improver: $improver
            outcome: (if $verdict.accept { "accepted" } else { "rejected" })
            reason: $verdict.reason
            summary: $summary
            files: $files
            parent: (git rev-parse --short HEAD | str trim)
            baseline_train_score: $baseline.train.score
            baseline_train_utility: $baseline.train.utility
            train_score: (if $candidate != null { $candidate.train.score })
            train_utility: (if $candidate != null { $candidate.train.utility })
            holdout_score: (if $candidate != null { $candidate.holdout.score })
        }
        if $verdict.accept {
            print $"ACCEPTED: ($verdict.reason)"
            record-attempt $agent $entry $patch
            git add -A
            git commit --quiet -m $"self-improve\(($agent)\): ($summary | str substring 0..<72)" -m $"Attempt ($attempt) by ($improver). ($verdict.reason)."
            $baseline = $candidate
        } else {
            print $"REJECTED: ($verdict.reason)"
            discard-changes
            record-attempt $agent $entry $patch
            git add -A
            git commit --quiet -m $"self-improve\(($agent)\): record rejected attempt ($attempt)" -m $verdict.reason
        }
    }
    print $"\nFinal for ($agent)"
    print $"train:   (fmt-summary $baseline.train)"
    print $"holdout: (fmt-summary $baseline.holdout)"
}

def main [] {
    print "Usage: nu improve/improve.nu <eval|run|history> <agent>   (see improve/README.md)"
}
