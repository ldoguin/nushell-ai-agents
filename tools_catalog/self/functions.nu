# Tools that let an agent inspect and modify the files agents are made
# of (prompts, tool definitions, tool implementations, memory).
#
# Must be used with "tool_call_mode": "json" in agents.json: each tool
# receives its arguments as one record. Paths are relative to the
# repository root and checked against improve/scope.json. This file is
# itself listed as protected there.
use ../../improve/scope.nu *

const MAX_READ_CHARS = 30000

def fail [msg: string] {
    $"ERROR: ($msg)"
}

# List a directory.
def list_files [args] {
    let rel = (try { repo-rel ($args.path? | default ".") } catch {|e| return (fail $e.msg) })
    if not (can-read $rel) { return (fail $"($rel) is not readable") }
    if not ($rel | path exists) { return (fail $"($rel) does not exist") }
    ls $rel
    | where {|f| can-read (repo-rel $f.name) }
    | each {|f| if $f.type == "dir" { $"($f.name)/" } else { $"($f.name)  \(($f.size)\)" } }
    | str join "\n"
}

# Read a text file.
def read_file [args] {
    let rel = (try { repo-rel $args.path } catch {|e| return (fail $e.msg) })
    if not (can-read $rel) { return (fail $"($rel) is not readable") }
    if ($rel | path type) != "file" { return (fail $"($rel) is not a file") }
    let content = (open --raw $rel | decode utf-8)
    let total = ($content | str length)
    if $total > $MAX_READ_CHARS {
        $"($content | str substring 0..<$MAX_READ_CHARS)\n[truncated: showing ($MAX_READ_CHARS) of ($total) characters]"
    } else {
        $content
    }
}

def checked [rel: string, done: string] {
    let problem = (check-file $rel)
    if $problem == null {
        $done
    } else {
        $"($done)\nWARNING: the file was saved but does not pass its syntax check. Fix it before finishing.\n($problem)"
    }
}

# Create or replace a file.
def write_file [args] {
    let rel = (try { repo-rel $args.path } catch {|e| return (fail $e.msg) })
    if not (can-write $rel) { return (fail $"($rel) is not writable. Writable areas: ((scope-config).writable | str join ', ')") }
    mkdir ($rel | path dirname)
    $args.content | save -f $rel
    checked $rel $"Wrote ($rel) \(($args.content | str length) characters\)."
}

# Replace one exact occurrence of a string in a file.
def edit_file [args] {
    let rel = (try { repo-rel $args.path } catch {|e| return (fail $e.msg) })
    if not (can-write $rel) { return (fail $"($rel) is not writable. Writable areas: ((scope-config).writable | str join ', ')") }
    if ($rel | path type) != "file" { return (fail $"($rel) is not a file") }
    if ($args.old_string | is-empty) { return (fail "old_string is empty") }
    let content = (open --raw $rel | decode utf-8)
    let parts = ($content | split row $args.old_string)
    let count = (($parts | length) - 1)
    if $count != 1 {
        return (fail $"old_string occurs ($count) times in ($rel); it must occur exactly once. Read the file and use a longer, exact excerpt.")
    }
    $parts | str join $args.new_string | save -f $rel
    checked $rel $"Edited ($rel)."
}

# Run another agent on one query and return its answer, to try a change.
def try_agent [args] {
    let depth = ($env.SELF_IMPROVE_DEPTH? | default "0" | into int)
    if $depth >= 1 { return (fail "try_agent cannot be nested") }
    if ($args.agent !~ '^\w+$') { return (fail "invalid agent name") }
    let r = (with-env { SELF_IMPROVE_DEPTH: ($depth + 1 | into string), TRY_AGENT: $args.agent, TRY_QUERY: $args.query } {
        ^$nu.current-exe --no-config-file -c 'use agent/agents.nu [run_named]; run_named $env.TRY_AGENT $env.TRY_QUERY' | complete
    })
    if $r.exit_code == 0 {
        $r.stdout
    } else {
        $"The agent failed \(exit ($r.exit_code)\):\n($r.stderr | ansi strip)\n($r.stdout)"
    }
}

# Append a short lesson to an agent's memory file (memory/<agent>.md).
# It is added to that agent's system prompt on later runs when its
# agents.json entry has "memory": "memory/<agent>.md".
def remember [args] {
    if ($args.agent !~ '^\w+$') { return (fail "invalid agent name") }
    let note = ($args.note | str trim | str replace --all "\n" " ")
    if ($note | is-empty) { return (fail "note is empty") }
    if ($note | str length) > 500 { return (fail "note is longer than 500 characters; keep lessons short") }
    let rel = $"memory/($args.agent).md"
    if not (can-write $rel) { return (fail $"($rel) is not writable") }
    mkdir memory
    $"- ($note)\n" | save --append $rel
    $"Saved to ($rel)."
}
