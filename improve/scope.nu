# What a self-modifying agent may read and write, as declared in
# improve/scope.json. Used twice on purpose: by the file tools the agent
# calls (tools_catalog/self/functions.nu) and, independently, by the
# improvement loop when it inspects what actually changed on disk
# (improve/improve.nu) -- so a bug or an edit in the tools cannot widen
# the scope on its own.
#
#   writable    path prefixes the agent may create or change
#   protected   exceptions inside `writable` that stay read-only
#   unreadable  path prefixes the agent may not even read (eval tasks and
#               run logs, so it cannot fit its changes to the held-out
#               tasks instead of fixing the agent)
# Everything else is read-only. Dotfiles are always off limits.

export def scope-config [] {
    open improve/scope.json
}

# Turn a path into a normalized path relative to the repository root
# (the current directory). Errors when it points outside the repository.
export def repo-rel [path: string] {
    let root = (pwd | path expand)
    let full = ($path | path expand)
    if $full == $root {
        return "."
    }
    if not ($full | str starts-with $"($root)/") {
        error make { msg: $"Path is outside the repository: ($path)" }
    }
    $full | path relative-to $root
}

def under [rel: string, prefixes: list] {
    $prefixes | any {|p| ($rel == $p) or ($rel | str starts-with $"($p)/") }
}

def hidden [rel: string] {
    $rel | path split | any {|part| ($part | str starts-with ".") and ($part != ".") }
}

export def can-read [rel: string] {
    (not (hidden $rel)) and (not (under $rel (scope-config).unreadable))
}

export def can-write [rel: string] {
    let cfg = (scope-config)
    (can-read $rel) and (under $rel $cfg.writable) and (not (under $rel $cfg.protected))
}

# Syntax check for the file types an agent is made of. Returns null when
# the file is fine (or is a type we do not check), else the problem.
export def check-file [rel: string] {
    let ext = ($rel | path parse | get extension)
    if $ext == "nu" {
        # Absolute path, passed through the environment: a child nu started
        # from a script resolves relative paths against the script's folder.
        let r = (with-env { CHECK_FILE: ($rel | path expand) } {
            ^$nu.current-exe --no-config-file -c 'nu-check --debug $env.CHECK_FILE' | complete
        })
        if $r.exit_code != 0 {
            return $"nushell parse error in ($rel):\n($r.stderr | ansi strip | str trim)"
        }
    } else if $ext == "json" {
        try { open --raw $rel | from json | ignore } catch {|e|
            return $"invalid JSON in ($rel): ($e.msg)"
        }
    }
    null
}
