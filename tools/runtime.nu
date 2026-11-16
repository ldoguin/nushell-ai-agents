# Tool execution for the agent loop.
#
# A tool is a nu function taking ONE record -- the model's parsed arguments --
# defined in the agent's `tool_functions` file and declared in its
# `model_tools` schema. `run-tool` is the only way the loop executes one, and
# it never raises: whatever happens, the caller gets
#
#     { ok: bool, content: string, error: string }
#
# which `tool-result-text` turns into the text the model sees.
#
# Safety properties (each covered in tests/test_tools.nu):
#   - the model's arguments are NEVER spliced into code: they are written to a
#     temp file and read back as data by the child process. The only things in
#     the code string are the functions file's path (from config) and the
#     function name, which must be declared in the agent's tool schema and be
#     a plain identifier.
#   - a name the agent did not declare is refused, so a model cannot reach
#     builtins (`rm`) or helpers that happen to be in the functions file.
#   - a per-tool policy (allow / ask / deny) is checked before anything runs.
#   - every call has a timeout and a cap on output size.

const POLICIES = ["allow" "ask" "deny"]
const DEFAULT_TIMEOUT = 2min
const DEFAULT_MAX_OUTPUT = 50000

# Build the runtime context stored on the agent from its config entry.
#   tool_functions  path of the nu file defining the tool functions
#   tool_policy     { default: "allow", <tool>: "allow" | "ask" | "deny" }
#                   (default falls back to $env.AGENT_TOOL_POLICY, then "allow")
#   tool_timeout    seconds a single tool call may run (default 120)
#   tool_shell      "nu" (default) or "cbsh" -- the shell tools run in
#                   (falls back to $env.TOOL_SHELL)
#   agents          names of other agents offered to this one as tools
export def tool-context [config: record, model_tools: list] {
    let subagents = ($config | get -o agents | default [])
    {
        functions: ($config | get -o tool_functions | default null)
        # every name the model may call: the declared tools plus the sub-agents
        names: (($model_tools | each {|t| $t.function.name }) | append $subagents)
        # the names among those that are other agents, run by the loop itself
        subagents: $subagents
        policy: ($config | get -o tool_policy | default {})
        timeout: (($config | get -o tool_timeout | default null) | if $in == null { $DEFAULT_TIMEOUT } else { $in * 1sec })
        shell: ($config | get -o tool_shell | default ($env.TOOL_SHELL? | default "nu"))
    }
}

# The policy that applies to one tool: its own entry, else the context's
# default, else $env.AGENT_TOOL_POLICY, else "allow".
export def tool-policy [ctx: record, name: string] {
    let policy = ($ctx.policy | get -o $name | default ($ctx.policy | get -o default | default ($env.AGENT_TOOL_POLICY? | default "allow")))
    if $policy not-in $POLICIES {
        error make { msg: $"Invalid tool policy '($policy)' for '($name)' -- must be one of: ($POLICIES | str join ', ')" }
    }
    $policy
}

# What the model is told about a finished call.
export def tool-result-text [result: record] {
    if $result.ok {
        $result.content
    } else if ($result.content | is-empty) {
        $"Error: ($result.error)"
    } else {
        $"Error: ($result.error)\n($result.content)"
    }
}

def failure [error: string, content: string = ""] {
    { ok: false, content: $content, error: $error }
}

# Ask the person at the terminal. Anything but an explicit yes -- including
# having no terminal to ask on -- is a no.
def confirm-tool [name: string, args: record] {
    if not (is-terminal --stdin) {
        return false
    }
    print $"Tool call: ($name) ($args | to json --raw)"
    (input "Run it? (y/N) " | str trim | str lowercase) in ["y" "yes"]
}

# The command that runs a tool, prefixed with `timeout` when the platform has
# it (GNU coreutils; `gtimeout` on macOS with coreutils installed).
def with-timeout [limit: duration] {
    let secs = (($limit / 1sec) | math ceil | into int)
    let bin = (["timeout" "gtimeout"] | where {|b| (which $b | is-not-empty) } | get -o 0)
    if $bin == null { [] } else { [$bin "--kill-after=5" $"($secs)"] }
}

def truncate-output [text: string] {
    let limit = ($env.AGENT_TOOL_MAX_OUTPUT? | default $DEFAULT_MAX_OUTPUT | into int)
    if ($text | str length) > $limit {
        $"($text | str substring 0..<$limit)\n[output truncated: ($text | str length) characters, showing the first ($limit)]"
    } else {
        $text
    }
}

# Everything that must hold before a call may run, in order: the name is one
# the agent declared (a tool or a sub-agent), the arguments are a JSON object,
# and the agent's policy allows it. Shared by tools and sub-agents.
# Returns { ok: true, name, args } or { ok: false, error }.
export def prepare-call [ctx: record, call: record] {
    let name = ($call | get -o name | default "")

    if $name not-in $ctx.names {
        return { ok: false, error: $"Unknown tool '($name)'. Available tools: ($ctx.names | str join ', ')" }
    }
    # Belt and braces: for a tool the name ends up in the code string.
    if ($name !~ '^[A-Za-z_][A-Za-z0-9_-]*$') {
        return { ok: false, error: $"Refusing tool name '($name)': not a plain identifier" }
    }

    let raw = ($call | get -o arguments | default {})
    let args = (if ($raw | describe) == "string" {
        if ($raw | str trim | is-empty) {
            {}
        } else {
            try { $raw | from json } catch { return { ok: false, error: $"Arguments for '($name)' are not valid JSON: ($raw | str substring 0..<200)" } }
        }
    } else {
        $raw
    })
    if ($args | describe | str starts-with "record") == false {
        return { ok: false, error: $"Arguments for '($name)' must be a JSON object, got: ($args | describe)" }
    }

    match (tool-policy $ctx $name) {
        "deny" => { return { ok: false, error: $"Tool '($name)' is not permitted by this agent's tool policy" } }
        "ask" => {
            if not (confirm-tool $name $args) {
                return { ok: false, error: $"Tool call '($name)' was not approved" }
            }
        }
        _ => {}
    }
    { ok: true, name: $name, args: $args }
}

# Run one tool call: { name: string, arguments: string (JSON) | record }.
export def run-tool [ctx: record, call: record] {
    let prepared = (prepare-call $ctx $call)
    if not $prepared.ok {
        return (failure $prepared.error)
    }
    let name = $prepared.name
    let args = $prepared.args
    if $name in $ctx.subagents {
        return (failure $"'($name)' is an agent, not a tool function; the agent loop runs it")
    }

    let functions = $ctx.functions
    if $functions == null {
        return (failure $"Tool '($name)' was requested but this agent has no tool_functions file")
    }
    let functions = ($functions | path expand)
    if not ($functions | path exists) {
        return (failure $"Tool functions file not found: ($functions)")
    }
    if ($functions =~ "['\"\n]") {
        return (failure $"Refusing tool functions path with quote characters: ($functions)")
    }

    let shell = $ctx.shell
    if $shell not-in ["nu" "cbsh"] {
        return (failure $"Invalid tool shell '($shell)' -- must be 'nu' or 'cbsh'")
    }

    # Arguments travel as data, in a file the child reads -- not on the command
    # line, not in the code, and not in an environment variable (size limits).
    let args_file = (mktemp --tmpdir agent-tool-args.XXXXXX)
    $args | to json | save --force $args_file
    let script = $"source '($functions)'; let a = \(open --raw $env.AGENT_TOOL_ARGS_FILE | from json\); let r = \(($name) $a\); print -n \(if \(\($r | describe\) == 'string'\) { $r } else { $r | to json }\)"
    let prefix = (with-timeout $ctx.timeout)
    let cmd = ($prefix | append [$shell "-c" $script])

    let out = (with-env { AGENT_TOOL_ARGS_FILE: $args_file } {
        ^($cmd | first) ...($cmd | skip 1) | complete
    })
    rm --force $args_file

    if $out.exit_code == 0 {
        { ok: true, content: (truncate-output $out.stdout), error: "" }
    } else if ($prefix | is-not-empty) and $out.exit_code in [124 137] {
        failure $"Tool '($name)' timed out after ($ctx.timeout)" (truncate-output $out.stdout)
    } else {
        let detail = ($out.stderr | str trim)
        failure (if ($detail | is-empty) { $"Tool '($name)' failed with exit code ($out.exit_code)" } else { truncate-output $detail }) (truncate-output $out.stdout)
    }
}
