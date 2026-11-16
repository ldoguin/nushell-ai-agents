# Shared helpers for the test suite.
use std/assert

const FAKE_LLM = (path self fixtures/fake_llm.py)

# Run `action` against a scripted fake LLM server and report what happened.
# `responses` is the server's script (see fixtures/fake_llm.py); `action` is
# called with the server's base URL, e.g. http://127.0.0.1:41234. Returns
#   { ok, value, error, requests }
# so a test can assert on a failure as easily as on a success, and always on
# exactly what the client sent. The server is stopped either way.
export def fake-llm [responses: list, action: closure] {
    let dir = (mktemp --directory)
    let script = ($dir | path join script.json)
    let requests = ($dir | path join requests.jsonl)
    let port_file = ($dir | path join port)
    $responses | to json | save $script
    let pid = (^bash -c $"python3 '($FAKE_LLM)' --script '($script)' --requests '($requests)' --port-file '($port_file)' >/dev/null 2>&1 & echo $!" | str trim)

    mut waited = 0
    while not ($port_file | path exists) {
        if $waited > 100 {
            ^kill $pid
            error make { msg: "fake LLM server did not start" }
        }
        sleep 50ms
        $waited += 1
    }
    # The port file is written before serve_forever(); give it a beat to listen.
    sleep 50ms
    let base = $"http://127.0.0.1:(open --raw $port_file | str trim)"

    let outcome = (try {
        { ok: true, value: (do $action $base), error: "" }
    } catch {|e|
        { ok: false, value: null, error: $e.msg }
    })

    ^kill $pid
    let seen = (if ($requests | path exists) {
        open --raw $requests | lines | where {|l| $l | is-not-empty } | each {|l| $l | from json }
    } else { [] })
    rm --recursive --force $dir
    $outcome | insert requests $seen
}

# A one-text-reply Anthropic Messages response.
export def anthropic-text [text: string] {
    { status: 200, body: { type: "message", role: "assistant", content: [{ type: "text", text: $text }], stop_reason: "end_turn", usage: { input_tokens: 7, output_tokens: 3 } } }
}

# A temp directory the test can write tool files into.
export def temp-dir [] {
    mktemp --directory
}

# The error message a closure raises, or null if it completes. (`complete` only
# captures external commands, not nu errors, so tests use this instead.)
export def error-of [action: closure] {
    try { do $action; null } catch {|e| $e.msg }
}

# Write a tool file + matching tool schema into a temp dir and return their
# paths. The tools take ONE record argument (the model's parsed arguments):
#   echo_tool { text }   -> "echo:<text>"
#   record_tool {}       -> a record (should reach the model as JSON)
#   fail_tool {}         -> raises
#   slow_tool {}         -> sleeps 5 seconds
export def make-tools [] {
    let dir = (mktemp --directory)
    let file = ($dir | path join tools.nu)
    '
def echo_tool [args] { $"echo:($args.text)" }
def record_tool [args] { { n: 1, tag: "x" } }
def fail_tool [args] { error make { msg: "boom" } }
def slow_tool [args] { sleep 5sec; "late" }
def injected [args] { "SHOULD NOT RUN" }
' | save $file
    let schema = (["echo_tool" "record_tool" "fail_tool" "slow_tool"] | each {|n|
        { type: "function", function: { name: $n, description: $"test tool ($n)", parameters: { type: "object", properties: { text: { type: "string" } } } } }
    })
    let schema_file = ($dir | path join tools.json)
    $schema | to json | save $schema_file
    { dir: $dir, functions: $file, schema: $schema_file }
}

# A mock-runtime agent config wired to `make-tools`' files.
export def mock-agent-config [responses: list, tools: record] {
    { runtime: "mock", responses: $responses, model_tools: $tools.schema, tool_functions: $tools.functions, options: {} }
}

# Write a manifest of mock agents next to the shared test tools and return its
# path. An entry with `tools: true` gets the echo/fail/slow test tools.
export def write-team [agents: record] {
    let t = (make-tools)
    let resolved = ($agents | items {|name, cfg|
        let base = ($cfg | reject -o tools)
        let full = (if ($cfg | get -o tools | default false) { $base | merge { model_tools: "tools.json", tool_functions: "tools.nu" } } else { $base })
        { k: $name, v: $full }
    } | reduce --fold {} {|e, acc| $acc | insert $e.k $e.v })
    let file = ($t.dir | path join agents.json)
    $resolved | to json | save $file
    $file
}
