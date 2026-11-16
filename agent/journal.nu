# Reading journals (agent/events.nu writes them) and replaying them to OTel.
#
# A journal is JSON lines, one event per line. A process that died mid-write
# leaves a truncated last line; the reader skips any line that is not a
# complete event instead of failing the whole file.
use sinks/otel.nu [with-closed-spans, export-events, exported-ids, events-to-batch]

# The events in a journal, in order.
export def read-journal [path: string] {
    if not ($path | path exists) {
        error make { msg: $"Journal not found: ($path)" }
    }
    open --raw $path
    | lines
    | each {|l|
        let event = (try { $l | from json } catch { null })
        if ($event | describe | str starts-with "record") and ("type" in ($event | columns)) { $event } else { null }
    }
    | compact
}

# Replay a journal to the OTel collector. Runs the process left unfinished are
# closed as incomplete (see with-closed-spans); spans already exported are
# skipped, so this is safe to repeat. Returns a summary record.
export def export-journal [path: string] {
    let events = (read-journal $path)
    let started = ($events | where type == "run.start" | get run_id)
    let finished = ($events | where type == "run.end" | get run_id)
    let incomplete = ($started | where {|r| $r not-in $finished })
    let closed = (with-closed-spans $events)
    let already = (exported-ids $path)
    let result = (export-events $closed $path)
    {
        journal: $path
        events: ($events | length)
        incomplete_runs: ($incomplete | length)
        exported_spans: ($result.exported | length)
        already_exported: ($closed | where {|e| ($e.type | str ends-with ".end") and ($e.span_id in $already) } | length)
        ok: $result.ok
        errors: $result.errors
    }
}

# Journal files in $env.AGENT_LOG_DIR (default logs/), oldest first.
export def list-journals [] {
    let dir = ($env.AGENT_LOG_DIR? | default "logs" | path expand)
    if not ($dir | path exists) {
        return []
    }
    glob $"($dir)/*.jsonl" | each {|f| { path: $f, modified: (ls $f | get 0.modified) } } | sort-by modified
}

# Export every journal that still has unexported spans or an unfinished run --
# the aftermath of a crash, or of a collector that was down at the time. Only
# journals untouched for `min_age` are considered, so one still being written
# by a live process is left alone.
export def recover-journals [min_age: duration = 10min] {
    let cutoff = ((date now) - $min_age)
    list-journals
    | where {|j| $j.modified < $cutoff }
    | each {|j|
        let events = (read-journal $j.path)
        let closed = (with-closed-spans $events)
        let pending = ($closed | where {|e| ($e.type | str ends-with ".end") and ($e.span_id not-in (exported-ids $j.path)) })
        if ($pending | is-empty) { null } else { export-journal $j.path }
    }
    | compact
}
