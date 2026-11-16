# Config validation and the manifest registry.
use std/assert
use lib.nu *
use ../agent/config.nu [resolve-config]
use ../agent/agents.nu [agent]
use ../agent/registry.nu [get-agent, list-agents, load-manifest]

def cfg-error [config: record, base: string = "/tmp"] {
    error-of { resolve-config $config $base "agent 'a'" }
}

export def test-unknown-keys-are-named-so-typos-are-caught [] {
    let msg = (cfg-error { runtime: "mock", tool_function: "x.nu" })
    assert ($msg | str contains "agent 'a': unknown key(s): tool_function")
}

export def test-runtime-and-model-are-required [] {
    assert ((cfg-error {}) | str contains "'runtime' is required")
    assert ((cfg-error { runtime: "gpt" }) | str contains "unknown runtime 'gpt'")
    assert ((cfg-error { runtime: "openai" }) | str contains "'model' is required for the openai runtime")
    assert ((cfg-error { runtime: "mock" }) == null) "mock needs no model"
}

export def test-missing-files-are-reported-with-their-full-path [] {
    let msg = (cfg-error { runtime: "mock", prompt: "nope/prompt.txt" } "/base/dir")
    assert ($msg | str contains "'prompt' file not found: /base/dir/nope/prompt.txt")
}

export def test-relative-paths-resolve-against-the-base-dir [] {
    let tools = (make-tools)
    let resolved = (resolve-config { runtime: "mock", model_tools: "tools.json", tool_functions: "tools.nu" } $tools.dir "a")
    assert equal $resolved.model_tools $tools.schema
    assert equal $resolved.tool_functions $tools.functions
}

export def test-folder-supplies-defaults-and-explicit-keys-win [] {
    let tools = (make-tools)
    cp $tools.functions ($tools.dir | path join functions.nu)
    "from folder" | save ($tools.dir | path join prompt.txt)
    "explicit" | save ($tools.dir | path join other.txt)
    let r = (resolve-config { runtime: "mock", folder: $tools.dir, prompt: "other.txt" } $tools.dir "a")
    assert equal $r.model_tools $tools.schema
    assert equal $r.tool_functions ($tools.dir | path join functions.nu)
    assert equal $r.prompt ($tools.dir | path join other.txt)
    assert ("folder" not-in ($r | columns))
    assert ((cfg-error { runtime: "mock", folder: "/no/such/dir" }) | str contains "folder not found")
}

export def test-schema-must-match-the-functions-file [] {
    let tools = (make-tools)
    # declare a tool nobody defines
    ((open $tools.schema) | append { type: "function", function: { name: "ghost_tool", description: "d", parameters: { type: "object" } } }) | to json | save --force $tools.schema
    let msg = (cfg-error { runtime: "mock", model_tools: $tools.schema, tool_functions: $tools.functions })
    assert ($msg | str contains "declared in the schema but not defined")
    assert ($msg | str contains "ghost_tool")
}

export def test-schema-problems-are-reported [] {
    let tools = (make-tools)
    let msg = (cfg-error { runtime: "mock", model_tools: $tools.schema })
    assert ($msg | str contains "no 'tool_functions' file defines them")

    let dup = ($tools.dir | path join dup.json)
    ((open $tools.schema | first) | wrap x | get x | [$in $in]) | to json | save $dup
    assert ((cfg-error { runtime: "mock", model_tools: $dup, tool_functions: $tools.functions }) | str contains "duplicate tool name(s): echo_tool")

    let junk = ($tools.dir | path join junk.json)
    '{"not":"a list"}' | save $junk
    assert ((cfg-error { runtime: "mock", model_tools: $junk, tool_functions: $tools.functions }) | str contains "'model_tools' must be a list")
}

export def test-numeric-and-policy-settings-are-validated [] {
    assert ((cfg-error { runtime: "mock", max_iterations: 0 }) | str contains "'max_iterations' must be a whole number >= 1")
    assert ((cfg-error { runtime: "mock", max_iterations: "9" }) | str contains "'max_iterations'")
    assert ((cfg-error { runtime: "mock", tool_timeout: -1 }) | str contains "'tool_timeout' must be a positive number")
    assert ((cfg-error { runtime: "mock", tool_policy: { t: "yolo" } }) | str contains "'tool_policy' for 't' is 'yolo'")
    assert ((cfg-error { runtime: "mock", tool_shell: "bash" }) | str contains "'tool_shell' must be 'nu' or 'cbsh'")
    assert ((cfg-error { runtime: "mock", options: "hot" }) | str contains "'options' must be an object")
    assert ((cfg-error { runtime: "mock", responses: "hi" }) | str contains "'responses' must be a list")
}

export def test-defaults-are-filled-in [] {
    let r = (resolve-config { runtime: "mock" } "/tmp" "a")
    assert equal $r.options {}
    assert equal $r.max_iterations 9
}

export def test-agent-record-carries-its-identity [] {
    let a = (agent { runtime: "anthropic", model: "claude-x", max_iterations: 4 } --name writer)
    assert equal ($a | select name runtime model max_iterations) { name: "writer", runtime: "anthropic", model: "claude-x", max_iterations: 4 }
    assert equal $a.messages []
}

# ------------------------------------------------------------ registry

def write-manifest [dir: string, agents: record] {
    let file = ($dir | path join agents.json)
    $agents | to json | save --force $file
    $file
}

export def test-manifest-paths-resolve-against-the-manifest-not-the-cwd [] {
    let tools = (make-tools)
    let manifest = (write-manifest $tools.dir { helper: { runtime: "mock", responses: ["hi"], model_tools: "tools.json", tool_functions: "tools.nu", description: "a helper" } })
    # cwd is somewhere else entirely
    let a = (get-agent helper --manifest $manifest)
    assert equal $a.tools.functions $tools.functions
    assert equal $a.name "helper"
}

export def test-unknown-agent-lists-what-exists [] {
    let dir = (temp-dir)
    let manifest = (write-manifest $dir { one: { runtime: "mock" }, two: { runtime: "mock" } })
    let msg = (error-of { get-agent three --manifest $manifest })
    assert ($msg | str contains "No agent named 'three'")
    assert ($msg | str contains "Available: one, two")
}

export def test-config-errors-name-the-agent [] {
    let dir = (temp-dir)
    let manifest = (write-manifest $dir { broken: { runtime: "mock", prompt: "missing.txt" } })
    assert ((error-of { get-agent broken --manifest $manifest }) | str contains "agent 'broken': 'prompt' file not found")
}

export def test-manifest-comes-from-the-env-when-not-given [] {
    let dir = (temp-dir)
    let manifest = (write-manifest $dir { only: { runtime: "mock", description: "d" } })
    let listed = (with-env { AGENTS_FILE: $manifest } { list-agents })
    assert equal $listed [{ name: "only", runtime: "mock", model: "", description: "d", agents: [] }]
}

export def test-bad-manifests-are-reported [] {
    let dir = (temp-dir)
    assert ((error-of { load-manifest ($dir | path join nope.json) }) | str contains "not found")
    "{ nope" | save ($dir | path join bad.json)
    assert ((error-of { load-manifest ($dir | path join bad.json) }) | str contains "is not valid JSON")
    "[1]" | save ($dir | path join list.json)
    assert ((error-of { load-manifest ($dir | path join list.json) }) | str contains "must be a JSON object")
}

export def test-every-agent-in-the-repo-manifest-is-valid [] {
    let names = (list-agents | get name)
    assert (($names | length) > 0)
    for name in $names {
        let msg = (error-of { get-agent $name })
        assert ($msg == null) $"agents.json entry '($name)' is invalid: ($msg)"
    }
}
