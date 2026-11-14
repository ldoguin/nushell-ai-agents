# The tool runtime: safe dispatch, policy, timeout, output handling.
use std/assert
use lib.nu *
use ../tools/runtime.nu *

def ctx [tools: record, extra: record = {}] {
    tool-context ({ tool_functions: $tools.functions } | merge $extra) (open $tools.schema)
}

def call-of [name: string, arguments: any] {
    { name: $name, arguments: $arguments }
}

export def test-runs-a-declared-tool [] {
    let r = (run-tool (ctx (make-tools)) (call-of echo_tool '{"text":"hi"}'))
    assert equal $r { ok: true, content: "echo:hi", error: "" }
}

export def test-accepts-record-arguments [] {
    # ollama delivers arguments as an object rather than a JSON string
    let r = (run-tool (ctx (make-tools)) (call-of echo_tool { text: "hi" }))
    assert equal $r.content "echo:hi"
}

export def test-empty-arguments-mean-no-arguments [] {
    let r = (run-tool (ctx (make-tools)) (call-of record_tool ""))
    assert $r.ok $r.error
}

export def test-arguments-are-data-never-code [] {
    let ctx = (ctx (make-tools))
    let hostile = [
        '"; injected {}; "'
        "'; injected {}; '"
        '$(injected {})'
        '`injected {}`'
        "line one\nline two; injected {}"
        '}; injected {}; {'
        '\" ; ^echo PWNED ; \"'
    ]
    for text in $hostile {
        let r = (run-tool $ctx (call-of echo_tool ({ text: $text } | to json)))
        assert $r.ok $"hostile text failed to run: ($text) -> ($r.error)"
        assert equal $r.content $"echo:($text)"
        assert (not ($r.content | str contains "SHOULD NOT RUN")) $"injected function ran for: ($text)"
    }
}

export def test-malformed-arguments-cannot-smuggle-commands [] {
    # The old runtime pasted the model's whole `arguments` string into `nu -c`,
    # so this ran `injected` (arbitrary code). Now it is just invalid JSON.
    for evil in ['{"text":"x"}; injected {}' '{"text":"x"} | injected {}' 'injected {}'] {
        let r = (run-tool (ctx (make-tools)) (call-of echo_tool $evil))
        assert (not $r.ok) $"should have refused: ($evil)"
        assert ($r.error | str contains "JSON") $"unexpected error for ($evil): ($r.error)"
        assert (not ($r.content | str contains "SHOULD NOT RUN"))
    }
}

export def test-refuses-tools-the-agent-did-not-declare [] {
    # `injected` exists in the functions file but is not in the schema
    let r = (run-tool (ctx (make-tools)) (call-of injected "{}"))
    assert (not $r.ok)
    assert ($r.error | str contains "Unknown tool 'injected'")
    assert ($r.error | str contains "echo_tool") "the model should be told what IS available"
    assert (not ($r.content | str contains "SHOULD NOT RUN"))
}

export def test-refuses-builtins-and-odd-names [] {
    let ctx = (ctx (make-tools))
    for name in ["rm" "echo_tool; ls" "echo_tool $a" "" "../x" "^ls"] {
        let r = (run-tool $ctx (call-of $name "{}"))
        assert (not $r.ok) $"'($name)' should be refused"
    }
}

export def test-rejects-invalid-json-arguments [] {
    let r = (run-tool (ctx (make-tools)) (call-of echo_tool '{"text": '))
    assert (not $r.ok)
    assert ($r.error | str contains "not valid JSON")
}

export def test-rejects-non-object-arguments [] {
    let r = (run-tool (ctx (make-tools)) (call-of echo_tool '[1,2]'))
    assert (not $r.ok)
    assert ($r.error | str contains "must be a JSON object")
}

export def test-tool-failure-is-a-result-not-a-crash [] {
    let r = (run-tool (ctx (make-tools)) (call-of fail_tool "{}"))
    assert (not $r.ok)
    assert ($r.error | str contains "boom")
    assert ((tool-result-text $r) | str starts-with "Error: ")
}

export def test-record_results-become-json [] {
    let r = (run-tool (ctx (make-tools)) (call-of record_tool "{}"))
    assert $r.ok $r.error
    assert equal ($r.content | from json) { n: 1, tag: "x" }
}

export def test-times-out [] {
    let started = (date now)
    let r = (run-tool (ctx (make-tools) { tool_timeout: 1 }) (call-of slow_tool "{}"))
    assert (not $r.ok)
    assert ($r.error | str contains "timed out")
    assert (((date now) - $started) < 4sec) "should have been killed well before the tool's 5s sleep ends"
}

export def test-truncates-huge-output [] {
    let r = (with-env { AGENT_TOOL_MAX_OUTPUT: "20" } {
        run-tool (ctx (make-tools)) (call-of echo_tool ({ text: (1..100 | each { "x" } | str join) } | to json))
    })
    assert $r.ok
    assert ($r.content | str contains "output truncated")
    assert (($r.content | str length) < 100)
}

export def test-missing-functions-file-is-reported [] {
    let tools = (make-tools)
    let r = (run-tool (tool-context { tool_functions: "/no/such/file.nu" } (open $tools.schema)) (call-of echo_tool "{}"))
    assert (not $r.ok)
    assert ($r.error | str contains "not found")
}

export def test-agent-without-functions-file-is-reported [] {
    let tools = (make-tools)
    let r = (run-tool (tool-context {} (open $tools.schema)) (call-of echo_tool "{}"))
    assert (not $r.ok)
    assert ($r.error | str contains "no tool_functions")
}

# ------------------------------------------------------------------ policy

export def test-policy-deny [] {
    let r = (run-tool (ctx (make-tools) { tool_policy: { echo_tool: "deny" } }) (call-of echo_tool '{"text":"x"}'))
    assert (not $r.ok)
    assert ($r.error | str contains "not permitted")
}

export def test-policy-ask-without-a-terminal-is-a-no [] {
    let r = (run-tool (ctx (make-tools) { tool_policy: { echo_tool: "ask" } }) (call-of echo_tool '{"text":"x"}'))
    assert (not $r.ok)
    assert ($r.error | str contains "not approved")
}

export def test-policy-per-tool-overrides-default [] {
    let ctx = (ctx (make-tools) { tool_policy: { default: "deny", echo_tool: "allow" } })
    assert ((run-tool $ctx (call-of echo_tool '{"text":"x"}')).ok)
    assert (not (run-tool $ctx (call-of record_tool "{}")).ok)
}

export def test-policy-default-comes-from-env [] {
    let ctx = (ctx (make-tools))
    let r = (with-env { AGENT_TOOL_POLICY: "deny" } { run-tool $ctx (call-of echo_tool '{"text":"x"}') })
    assert (not $r.ok)
    assert ($r.error | str contains "not permitted")
}

export def test-invalid-policy-value-is-an-error [] {
    let msg = (error-of { tool-policy { policy: { echo_tool: "yolo" } } "echo_tool" })
    assert ($msg | str contains "Invalid tool policy 'yolo'")
}

# ----------------------------------------------------------- result text

export def test-result-text [] {
    assert equal (tool-result-text { ok: true, content: "fine", error: "" }) "fine"
    assert equal (tool-result-text { ok: false, content: "", error: "bad" }) "Error: bad"
    assert equal (tool-result-text { ok: false, content: "partial", error: "bad" }) "Error: bad\npartial"
}

# --------------------------------------------------------- library tools

use ../tools/tools.nu [calculate, get_planet_mass, ask_repo]

export def test-calculate-does-arithmetic [] {
    assert equal (calculate { expression: "2 x 3 + 4" }) "10"
    assert equal (calculate { expression: "(1 + 2) * 4 - 6" }) "6"
    assert equal (calculate { expression: "2 ^ 10" }) "1024"
}

export def test-calculate-refuses-anything-but-arithmetic [] {
    for evil in ["1; ^echo pwned" "ls" "1 + (rm -rf x)" "$env.HOME" "1 | save /tmp/pwned"] {
        let msg = (error-of { calculate { expression: $evil } })
        assert ($msg | str contains "Not an arithmetic expression") $"should have refused: ($evil)"
    }
}

export def test-planet-mass-takes-a-record [] {
    assert equal (get_planet_mass { planet: "Mars" }) 6.39e23
}

export def test-cbsh-tools-pass-arguments-as-environment-not-code [] {
    let dir = (make-tools).dir
    let bin = ($dir | path join bin)
    mkdir $bin
    '#!/bin/sh\necho "ARGS:$*"\necho "NAME:$ASK_REPO_NAME"\n' | str replace --all '\n' (char nl) | save ($bin | path join cbsh)
    chmod +x ($bin | path join cbsh)
    let evil = 'x"; ^echo PWNED; "'
    let out = (with-env { PATH: ($env.PATH | prepend $bin) } { ask_repo { repoName: $evil, question: "q" } })
    # the command line cbsh was given is constant...
    assert ($out | str contains "ARGS:-c source tools/cbsh.nu; ask_repo $env.ASK_REPO_NAME $env.ASK_REPO_QUESTION")
    # ...and the hostile value arrived only as data
    assert ($out | str contains $"NAME:($evil)")
}
