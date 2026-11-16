# Validation and path resolution for one agent's config entry (an entry of an
# agents.json manifest). Everything that can be wrong with a config is reported
# here, when it is loaded, in one message that names the agent and the problem
# -- not three tool calls into a run.
#
#   runtime          openai | ollama | anthropic | bedrock | mock      (required)
#   model            model id; required except for mock
#   description      what the agent is for (shown in listings; used when the
#                    agent is offered to another agent as a tool)
#   prompt           path of the system prompt text file
#   model_tools      path of the tool schema JSON (an OpenAI-style tools list)
#   tool_functions   path of the nu file defining those tools
#   folder           a directory holding prompt.txt / tools.json /
#                    functions.nu: defaults for the three keys above, which
#                    win when given explicitly
#   options          passed through to the provider (temperature, max_tokens, ...)
#   max_iterations   model calls the loop may take (default 9)
#   tool_policy / tool_timeout / tool_shell   see tools/runtime.nu
#   agents           names of other agents in the same manifest, offered to
#                    this one as tools: each becomes a tool named after the
#                    agent, taking a `query`, that runs that agent on a fresh
#                    conversation and returns its answer
#   responses        mock runtime only: the scripted replies
#
# Relative paths resolve against the directory of the manifest the entry came
# from (or the current directory for a config given directly), so a manifest
# works from anywhere.

const RUNTIMES = ["openai" "ollama" "anthropic" "bedrock" "mock"]
const KEYS = [runtime model description prompt model_tools tool_functions folder options max_iterations tool_policy tool_timeout tool_shell responses agents]
const PATH_KEYS = [prompt model_tools tool_functions]

def bad [label: string, msg: string] {
    error make { msg: $"($label): ($msg)" }
}

def resolve-path [base: string, p: string] {
    [$base $p] | path join | path expand
}

# Validate `config` and return it with every path made absolute, `options` and
# `max_iterations` defaulted, and `folder` expanded.
export def resolve-config [config: record, base_dir: string, label: string = "agent"] {
    let unknown = ($config | columns | where {|k| $k not-in $KEYS })
    if ($unknown | is-not-empty) {
        bad $label $"unknown key\(s\): ($unknown | str join ', '). Known keys: ($KEYS | str join ', ')"
    }

    let runtime = ($config | get -o runtime | default "")
    if ($runtime | is-empty) {
        bad $label $"'runtime' is required \(one of: ($RUNTIMES | str join ', ')\)"
    }
    if $runtime not-in $RUNTIMES {
        bad $label $"unknown runtime '($runtime)' -- expected one of: ($RUNTIMES | str join ', ')"
    }
    if $runtime != "mock" and ($config | get -o model | default "" | is-empty) {
        bad $label $"'model' is required for the ($runtime) runtime"
    }

    # folder supplies defaults for whichever of its three files exist
    mut merged = $config
    let folder = ($config | get -o folder | default null)
    if $folder != null {
        let dir = (resolve-path $base_dir $folder)
        if not ($dir | path exists) {
            bad $label $"folder not found: ($dir)"
        }
        let defaults = ({ prompt: "prompt.txt", model_tools: "tools.json", tool_functions: "functions.nu" }
            | items {|k, v| { k: $k, v: ($dir | path join $v) } }
            | where {|e| $e.v | path exists }
            | reduce --fold {} {|e, acc| $acc | insert $e.k $e.v })
        $merged = ($defaults | merge ($config | reject folder))
    }

    for key in $PATH_KEYS {
        let p = ($merged | get -o $key | default null)
        if $p != null {
            let full = (resolve-path $base_dir $p)
            if not ($full | path exists) {
                bad $label $"'($key)' file not found: ($full)"
            }
            $merged = ($merged | upsert $key $full)
        }
    }

    let options = ($merged | get -o options | default {})
    if ($options | describe | str starts-with "record") == false {
        bad $label "'options' must be an object"
    }
    let iterations = ($merged | get -o max_iterations | default 9)
    if ($iterations | describe) != "int" or $iterations < 1 {
        bad $label $"'max_iterations' must be a whole number >= 1, got: ($iterations)"
    }
    let timeout = ($merged | get -o tool_timeout | default null)
    if $timeout != null and ((($timeout | describe) not-in ["int" "float"]) or $timeout <= 0) {
        bad $label $"'tool_timeout' must be a positive number of seconds, got: ($timeout)"
    }
    let policy = ($merged | get -o tool_policy | default {})
    if ($policy | describe | str starts-with "record") == false {
        bad $label "'tool_policy' must be an object such as { \"default\": \"allow\", \"some_tool\": \"ask\" }"
    }
    for p in ($policy | transpose tool value) {
        if $p.value not-in ["allow" "ask" "deny"] {
            bad $label $"'tool_policy' for '($p.tool)' is '($p.value)' -- must be allow, ask or deny"
        }
    }
    let shell = ($merged | get -o tool_shell | default "nu")
    if $shell not-in ["nu" "cbsh"] {
        bad $label $"'tool_shell' must be 'nu' or 'cbsh', got: ($shell)"
    }
    if $runtime == "mock" and (($merged | get -o responses | default []) | describe | str replace --regex '^(table|list).*' 'list') != "list" {
        bad $label "'responses' must be a list for the mock runtime"
    }

    let agents = ($merged | get -o agents | default [])
    if ($agents | describe | str replace --regex '^(table|list).*' 'list') != "list" {
        bad $label "'agents' must be a list of agent names"
    }
    for a in $agents {
        if ($a | describe) != "string" or ($a !~ '^[A-Za-z0-9_-]{1,64}$') {
            bad $label $"'agents' entry '($a)' is not usable as a tool name -- agent names used this way must be 1-64 letters, digits, '_' or '-'"
        }
    }
    let repeated = ($agents | uniq --repeated)
    if ($repeated | is-not-empty) {
        bad $label $"'agents' lists ($repeated | str join ', ') more than once"
    }

    # the schema must be a well-formed tools list whose functions exist
    let schema_file = ($merged | get -o model_tools | default null)
    if $schema_file != null {
        let tools = (try { open $schema_file } catch {|e| bad $label $"'model_tools' is not valid JSON \(($schema_file)\): ($e.msg)" })
        let names = (try { $tools | each {|t| $t.function.name } } catch { bad $label $"'model_tools' must be a list of { type: \"function\", function: { name, ... } } entries \(($schema_file)\)" })
        let dupes = ($names | uniq --repeated)
        if ($dupes | is-not-empty) {
            bad $label $"'model_tools' declares duplicate tool name\(s\): ($dupes | str join ', ')"
        }
        let clashes = ($names | where {|n| $n in $agents })
        if ($clashes | is-not-empty) {
            bad $label $"'agents' and 'model_tools' both define a tool named ($clashes | str join ', ')"
        }
        let functions_file = ($merged | get -o tool_functions | default null)
        if $functions_file == null {
            bad $label "'model_tools' declares tools but no 'tool_functions' file defines them"
        }
        let source = (open --raw $functions_file)
        let missing = ($names | where {|n| not ($source =~ $"\(?m\)^\\s*\(export\\s+\)?def\\s+\(--env\\s+\)?\"?($n)\"?\\s") })
        if ($missing | is-not-empty) {
            bad $label $"tool\(s\) declared in the schema but not defined in ($functions_file): ($missing | str join ', ')"
        }
    }

    $merged | upsert options $options | upsert max_iterations $iterations | upsert agents $agents
}
