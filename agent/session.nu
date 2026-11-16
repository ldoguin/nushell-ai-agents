# Sessions: a conversation that outlives a process. `run-agent --session <id>`
# (agent/loop.nu) snapshots the conversation to <AGENT_SESSION_DIR>/<id>.json
# (default sessions/) and a later run with the same id continues from it --
# including a run that was killed part-way.
#
# A snapshot is the conversation itself, not a log of it: it holds the messages
# the next model call needs, whether or not event content is being captured,
# and is written
#   - when a run starts (status "running"), so a crash in the first model call
#     can be resumed without retyping the question,
#   - after every COMPLETED tool round, so it never holds an assistant message
#     whose tool calls have no results (providers reject that), and
#   - when the run ends, with its final status.
# A tool round that was in flight when the process died is simply redone on
# resume: the model is asked again and will usually repeat the calls.
#
# Writes are atomic (temp file, then rename) and the files are mode 0600, since
# a conversation can hold anything a user or a tool said. Each snapshot carries
# a `rev`; a write is refused if the file's rev is not the one this process
# loaded, so two processes continuing the same session cannot silently
# overwrite each other.
#
# Snapshot: { v, id, agent, runtime, model, status, rev, created, updated,
#             runs, messages, usage_total }
# `usage_total` is cumulative across every run of the session.

const VERSION = 1

export def session-dir [] {
    $env.AGENT_SESSION_DIR? | default "sessions" | path expand
}

# A session id becomes a file name, so it is restricted to a safe alphabet.
export def check-session-id [id: string] {
    if ($id !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$') {
        error make { msg: $"Invalid session id '($id)': use 1-128 letters, digits, '.', '_' or '-', starting with a letter or digit" }
    }
    $id
}

def session-file [id: string] {
    session-dir | path join $"(check-session-id $id).json"
}

# The session with this id, or null if there is none. Raises if the file exists
# but cannot be read as a session.
export def load-session [id: string] {
    let file = (session-file $id)
    if not ($file | path exists) {
        return null
    }
    let session = (try { open $file } catch {|e| error make { msg: $"Session '($id)' is unreadable \(($file)\): ($e.msg)" } })
    if ($session | describe | str starts-with "record") == false or ("messages" not-in ($session | columns)) or ("rev" not-in ($session | columns)) {
        error make { msg: $"Session '($id)' is corrupt \(($file)\): not a session snapshot" }
    }
    if $session.v > $VERSION {
        error make { msg: $"Session '($id)' was written by a newer version of this harness \(snapshot v($session.v), this is v($VERSION)\)" }
    }
    $session
}

# Write a snapshot. `session` must carry the `rev` it was loaded with (0 for a
# new session). Returns { ok, session, conflict, error }: `session` is the saved
# snapshot (rev + 1); a `conflict` means another process saved in between and
# nothing was written; any other failure (disk full, ...) is just `ok: false`.
export def save-session [session: record] {
    let id = (check-session-id $session.id)
    let file = (session-file $id)
    let on_disk = (try {
        if ($file | path exists) { open $file | get -o rev | default 0 } else { 0 }
    } catch { -1 })
    if $on_disk != $session.rev {
        return { ok: false, session: $session, conflict: true, error: $"Session '($id)' was modified by another process \(on disk rev ($on_disk), this run started from rev ($session.rev)\); not overwriting it" }
    }
    let next = ($session | merge { v: $VERSION, rev: ($session.rev + 1), updated: (date now | format date "%Y-%m-%dT%H:%M:%SZ") })
    try {
        let dir = (session-dir)
        if not ($dir | path exists) {
            mkdir $dir
            if $nu.os-info.name != "windows" { ^chmod 700 $dir }
        }
        let tmp = $"($file).tmp-(random uuid | str substring 0..<8)"
        $next | to json --raw | save --force $tmp
        if $nu.os-info.name != "windows" { ^chmod 600 $tmp }
        mv --force $tmp $file
        { ok: true, session: $next, conflict: false, error: "" }
    } catch {|e|
        { ok: false, session: $session, conflict: false, error: $e.msg }
    }
}

# All sessions, most recently updated first (without their messages).
export def list-sessions [] {
    let dir = (session-dir)
    if not ($dir | path exists) {
        return []
    }
    glob $"($dir)/*.json" | each {|f|
        try {
            let s = (open $f)
            {
                id: $s.id, agent: $s.agent, status: $s.status, runs: $s.runs
                messages: ($s.messages | length), total_tokens: ($s.usage_total.total_tokens? | default 0)
                updated: $s.updated
            }
        } catch { null }
    } | compact | sort-by updated --reverse
}
