# The event layer. The loop reports what happens as typed event records and
# knows nothing about where they go; sinks (agent/sinks/*.nu) consume them.
#
#   jsonl    every event appended to a journal file as it happens (JSON lines).
#            The journal is the durable record: a crash, OOM kill or timeout
#            loses nothing already emitted, and `agent-export` can replay it.
#   console  one-line progress on stderr
#   otel     exports spans/metrics/logs to an OTLP collector, in batches at the
#            end of each iteration and at the end of the run
#
# Selected with $env.AGENT_SINKS ("jsonl,console,otel") or `--sinks`. The
# default is none: a plain run writes no files and sends nothing. The journal
# is written whenever `jsonl` or `otel` is selected, since without it there is
# nothing to recover after a crash.
#
# State lives in a run context threaded through the loop (nu has no globals):
#   $ctx = (emit $ctx "tool.start" { ... })
# `emit` returns the context with its sequence number advanced. Everything a
# sink needs that is mutable -- the journal path (cleared if writing fails),
# the events not yet exported -- is in it.
#
# EVENT SCHEMA (v1) -- every event has:
#   v, ts (UTC RFC 3339), ts_ns, seq (per run, from 1 -- a gap means loss),
#   type, run_id, parent_run_id (null for a root run), depth, agent, trace_id
# and, by type:
#   run.start        span_id, parent_span_id, runtime, model, max_iterations
#   run.end          span_id, parent_span_id, start_ns, status, iterations, usage, error
#   iteration.start  span_id, parent_span_id, iteration
#   iteration.end    span_id, parent_span_id, start_ns, iteration, finish_reason, error
#   model.start      span_id, parent_span_id, messages
#   model.end        span_id, parent_span_id, start_ns, ok, duration_ms, usage, cost,
#                    finish_reason, retries, error
#   tool.start       span_id, parent_span_id, tool, call_id
#   tool.end         span_id, parent_span_id, start_ns, tool, call_id, ok, duration_ms,
#                    error, child_run_id (when the tool was a sub-agent)
# Start events exist for the journal: a start with no matching end (same
# span_id) means the process died inside that model call or tool. End events
# repeat start_ns so a consumer needs nothing but the end event to build a span.
# Payload text -- prompts, tool arguments and results, the raw model reply --
# is under `content`, omitted unless $env.AGENT_LOG_CONTENT is not "false",
# and clipped to $env.AGENT_LOG_MAX_CONTENT characters (default 20000).
use sinks/console.nu
use sinks/otel.nu

const KNOWN_SINKS = ["jsonl" "console" "otel"]

export def now-ns [] {
    date now | into int
}

# A random hex id: 16 characters for a span, 32 for a trace.
export def new-id [n: int] {
    let base = (random uuid | str replace --all "-" "")
    $"($base)($base)" | str substring 0..<$n
}

def warn [message: string] {
    print --stderr $"warning: ($message)"
}

# The sinks selected by $env.AGENT_SINKS, validated.
export def configured-sinks [] {
    let sinks = ($env.AGENT_SINKS? | default "" | split row "," | each {|s| $s | str trim } | where {|s| $s | is-not-empty })
    let unknown = ($sinks | where {|s| $s not-in $KNOWN_SINKS })
    if ($unknown | is-not-empty) {
        error make { msg: $"Unknown sink\(s\) in AGENT_SINKS/--sinks: ($unknown | str join ', '). Known: ($KNOWN_SINKS | str join ', ')" }
    }
    $sinks
}

# The context for one run. `parent` is either empty (a root run), an external
# trace position { trace_id, span_id } to nest under, or what `child-parent`
# returns, in which case the sinks, journal and settings are inherited so the
# whole tree of runs shares one journal.
export def run-context [agent: record, parent: record, depth: int, sinks: any] {
    let inherited = ("journal" in $parent)
    let sinks = (if $sinks != null {
        $sinks
    } else if $inherited {
        $parent.sinks
    } else {
        configured-sinks
    })
    let unknown = ($sinks | where {|s| $s not-in $KNOWN_SINKS })
    if ($unknown | is-not-empty) {
        error make { msg: $"Unknown sink\(s\): ($unknown | str join ', '). Known: ($KNOWN_SINKS | str join ', ')" }
    }

    let run_id = (random uuid)
    let capture = (if $inherited { $parent.capture } else { ($env.AGENT_LOG_CONTENT? | default "true" | str lowercase) != "false" })
    let max_content = (if $inherited { $parent.max_content } else { $env.AGENT_LOG_MAX_CONTENT? | default 20000 | into int })

    let wants_journal = ("jsonl" in $sinks) or ("otel" in $sinks and not (otel-disabled-by-env))
    let journal = (if $inherited {
        $parent.journal
    } else if $wants_journal {
        open-journal $run_id
    } else {
        null
    })

    {
        run_id: $run_id
        parent_run_id: ($parent | get -o run_id | default null)
        depth: $depth
        agent: ($agent | get -o name | default "")
        trace_id: ($parent | get -o trace_id | default (new-id 32))
        parent_span_id: ($parent | get -o span_id | default null)
        sinks: $sinks
        journal: $journal
        capture: $capture
        max_content: $max_content
        seq: 0
        pending: []
    }
}

def otel-disabled-by-env [] {
    ($env.OTEL_SDK_DISABLED? | default "" | into string | str lowercase) in ["true" "1" "yes"]
}

# Create the root run's journal: <AGENT_LOG_DIR>/<timestamp>-<run id>.jsonl,
# readable only by its owner (it can hold prompts and tool output). Returns
# null, after a warning, if it cannot be created -- logging must never stop a run.
def open-journal [run_id: string] {
    let dir = ($env.AGENT_LOG_DIR? | default "logs" | path expand)
    let file = ($dir | path join $"(date now | format date '%Y%m%dT%H%M%S')-($run_id).jsonl")
    try {
        mkdir $dir
        "" | save --force $file
        if $nu.os-info.name != "windows" {
            ^chmod 600 $file
        }
        $file
    } catch {|e|
        warn $"cannot write the event journal in ($dir): ($e.msg) -- continuing without it"
        null
    }
}

# What a child run needs from its parent run: where to nest (the tool call's
# span) and the shared sinks, journal and settings.
export def child-parent [ctx: record, span_id: string] {
    {
        trace_id: $ctx.trace_id
        span_id: $span_id
        run_id: $ctx.run_id
        sinks: $ctx.sinks
        journal: $ctx.journal
        capture: $ctx.capture
        max_content: $ctx.max_content
    }
}

def clip [text: any, limit: int] {
    let s = (if ($text | describe) == "string" { $text } else { $text | to json --raw })
    if ($s | str length) > $limit {
        $"($s | str substring 0..<$limit)…[truncated, ($s | str length) characters]"
    } else {
        $s
    }
}

# Record an event: append it to the journal, show it on the console, queue it
# for export. `fields` are the type-specific fields (see the schema above);
# put payload text in `fields.content`. Returns the updated context.
export def emit [ctx: record, type: string, fields: record = {}] {
    let content = ($fields | get -o content | default {})
    let base = ($fields | reject -o content)
    let seq = ($ctx.seq + 1)
    # a caller that measured its own start time passes it as `ts_ns`, so a start
    # event and the end event's start_ns agree exactly
    let now = ($fields | get -o ts_ns | default (now-ns))
    mut event = ({
        v: 1
        ts: ($now | into datetime | date to-timezone UTC | format date "%Y-%m-%dT%H:%M:%S%.3fZ")
        ts_ns: $now
        seq: $seq
        type: $type
        run_id: $ctx.run_id
        parent_run_id: $ctx.parent_run_id
        depth: $ctx.depth
        agent: $ctx.agent
        trace_id: $ctx.trace_id
    } | merge $base)
    if $ctx.capture and ($content | is-not-empty) {
        $event = ($event | insert content ($content | items {|k, v| [$k (clip $v $ctx.max_content)] } | into record))
    }

    # Append to the journal first: it is the durable record. A failure
    # (disk full, directory removed) warns once and stops journaling for the
    # rest of the run; it never stops the run itself.
    let journaled = (if $ctx.journal == null {
        true
    } else {
        try {
            $"($event | to json --raw)\n" | save --append $ctx.journal
            true
        } catch {|e|
            warn $"cannot append to the event journal ($ctx.journal): ($e.msg) -- continuing without it"
            false
        }
    })
    mut next = ($ctx | upsert seq $seq)
    if not $journaled {
        $next = ($next | upsert journal null)
    }
    if "console" in $ctx.sinks {
        try { console on-event $event } catch {|e| null }
    }
    if "otel" in $ctx.sinks {
        $next = ($next | upsert pending ($next.pending | append $event))
    }
    $next
}

# Export what has been queued (the OTel sink). Called at the end of each
# iteration and of the run, so a crash costs at most the current iteration from
# the live feed -- and even that is in the journal for `agent-export`.
export def flush [ctx: record] {
    if ("otel" not-in $ctx.sinks) or ($ctx.pending | is-empty) {
        return ($ctx | upsert pending [])
    }
    let result = (otel export-events $ctx.pending $ctx.journal)
    if not $result.ok {
        let kept = (if $ctx.journal != null { " -- the events are in the journal; replay them with `agent-export`" } else { "" })
        warn $"OTel export failed: ($result.errors | str join '; ')($kept)"
    }
    $ctx | upsert pending []
}
