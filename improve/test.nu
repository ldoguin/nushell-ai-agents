#!/usr/bin/env nu
# End-to-end test of the self-improvement loop. Needs no API key: every
# agent uses the scripted "mock" runtime. Run from the repository root:
#
#   nu improve/test.nu
#
# It copies the harness into a temporary git repository, adds a target
# agent with a deliberately incomplete tool, and checks that the loop
# keeps a change that fixes it and throws away changes that break it,
# do not parse, or land outside the writable scope.

def check [name: string, cond: bool] {
    if $cond {
        print $"ok    ($name)"
    } else {
        print $"FAIL  ($name)"
        error make { msg: $"check failed: ($name)" }
    }
}

def --wrapped improve [...args: string] {
    ^$nu.current-exe --no-config-file improve/improve.nu ...$args | complete
}

def last-attempt [] {
    open --raw improve/archive/shop.jsonl | lines | last | from json
}

def main [--keep] {
    let src = (pwd)
    let box = (mktemp -d -t self-improve-test.XXXXXX)
    for d in [agent common tools] { cp -r $d $box }
    mkdir $"($box)/improve" $"($box)/tools_catalog" $"($box)/fixtures" $"($box)/evals"
    for f in [eval.nu improve.nu scope.nu scope.json] { cp $"improve/($f)" $"($box)/improve/" }
    cp -r tools_catalog/self $"($box)/tools_catalog/"
    "logs/*\n" | save $"($box)/.gitignore"
    cd $box

    # --- the target: answers with whatever its `lookup` tool returns ---
    mkdir tools_catalog/shop tools_catalog/rogue
    "You answer questions about prices using the lookup tool." | save tools_catalog/shop/prompt.txt
    [{ type: "function", function: { name: "lookup", description: "Return the price list.", parameters: { type: "object", properties: {}, required: [] } } }] | to json | save tools_catalog/shop/tools.json
    "def lookup [args] {\n    \"apple=3\"\n}\n" | save tools_catalog/shop/functions.nu
    [{ tool_calls: [{ name: "lookup", arguments: {} }] }, { content: "Answer: {{last_tool}}" }] | to json | save fixtures/shop.json
    {
        token_cap: 1000, time_cap_sec: 60,
        tasks: [
            { id: "apple", query: "price of an apple?", expect: { contains: ["apple=3"] } }
            { id: "pear", query: "price of a pear?", expect: { contains: ["pear=5"] } }
            { id: "plum", query: "price of a plum?", expect: { contains: ["plum=7"] }, split: "holdout" }
        ]
    } | to json | save evals/shop.json

    # --- scripted improvers ---
    let fixed = "def lookup [args] {\n    \"apple=3 (a) pear=5 \\\"plum=7\\\" $x\"\n}\n"
    [
        { tool_calls: [{ name: "read_file", arguments: { path: "tools_catalog/shop/functions.nu" } }] }
        { tool_calls: [{ name: "edit_file", arguments: { path: "tools_catalog/shop/functions.nu", old_string: "\"apple=3\"", new_string: "\"apple=3 (a) pear=5 \\\"plum=7\\\" $x\"" } }] }
        { tool_calls: [{ name: "remember", arguments: { agent: "shop", note: "The price list must cover every fruit." } }] }
        { content: "Answer: added the missing prices to lookup" }
    ] | to json | save fixtures/fixer.json
    [
        { tool_calls: [{ name: "write_file", arguments: { path: "tools_catalog/shop/functions.nu", content: "def lookup [args] {\n    \"nothing\"\n}\n" } }] }
        { content: "Answer: simplified lookup" }
    ] | to json | save fixtures/breaker.json
    [
        { tool_calls: [{ name: "write_file", arguments: { path: "tools_catalog/shop/functions.nu", content: "def lookup [args {" } }] }
        { content: "Answer: rewrote lookup" }
    ] | to json | save fixtures/syntax.json
    [
        { tool_calls: [{ name: "write_file", arguments: { path: "improve/scope.json", content: "{}" } }, { name: "read_file", arguments: { path: "evals/shop.json" } }] }
        { content: "Answer: {{last_tool}}" }
    ] | to json | save fixtures/escaper.json
    # an improver whose own tools ignore the scope, to test the loop's check
    "def write_anywhere [args] {\n    $args.content | save -f $args.path\n    \"done\"\n}\n" | save tools_catalog/rogue/functions.nu
    [
        { tool_calls: [{ name: "write_anywhere", arguments: { path: "agent/hack.nu", content: "# hi" } }] }
        { content: "Answer: wrote outside" }
    ] | to json | save fixtures/rogue.json
    [{ content: "{{system}}" }] | to json | save fixtures/echo.json

    let improver = {|script| { runtime: "mock", folder: "tools_catalog/self", tool_call_mode: "json", max_iterations: 12, options: { script: $script } } }
    {
        shop: { runtime: "mock", folder: "tools_catalog/shop", memory: "memory/shop.md", options: { script: "fixtures/shop.json" } }
        echo: { runtime: "mock", prompt: "tools_catalog/shop/prompt.txt", memory: "memory/shop.md", options: { script: "fixtures/echo.json" } }
        fixer: (do $improver "fixtures/fixer.json")
        breaker: (do $improver "fixtures/breaker.json")
        syntax: (do $improver "fixtures/syntax.json")
        escaper: (do $improver "fixtures/escaper.json")
        rogue: { runtime: "mock", tool_functions: "tools_catalog/rogue/functions.nu", tool_call_mode: "json", options: { script: "fixtures/rogue.json" } }
    } | to json | save agents.json

    ^git init --quiet --initial-branch main
    ^git config user.email "test@example.com"
    ^git config user.name "test"
    ^git add -A
    ^git commit --quiet -m "fixture"

    # --- guards ---
    let r = (improve run shop --improver fixer -n 1)
    check "refuses to run on main" (($r.exit_code != 0) and ($r.stderr =~ "Refusing"))
    ^git checkout --quiet -b work
    "x" | save stray.txt
    let r = (improve run shop --improver fixer -n 1)
    check "refuses a dirty working tree" (($r.exit_code != 0) and ($r.stderr =~ "uncommitted"))
    rm stray.txt

    # --- eval ---
    let r = (improve eval shop)
    check "eval reports the baseline 1/2 train, 0/1 holdout" (($r.stdout =~ 'train:\s+1/2 passed') and ($r.stdout =~ 'holdout:\s+0/1 passed'))

    # --- rejected attempts leave no trace except the archive ---
    let original = (open --raw tools_catalog/shop/functions.nu)
    let r = (improve run shop --improver breaker -n 1)
    check "a change that lowers the score is rejected" ((last-attempt).reason =~ "train score dropped")
    check "and reverted" ((open --raw tools_catalog/shop/functions.nu) == $original)
    check "its patch is archived" ("improve/archive/shop/1.patch" | path exists)

    let r = (improve run shop --improver syntax -n 1)
    check "a change that does not parse is rejected before evaluation" (((last-attempt).reason =~ "does not parse") and ((last-attempt).train_score == null))
    check "and reverted" ((open --raw tools_catalog/shop/functions.nu) == $original)

    let r = (improve run shop --improver escaper -n 1)
    check "the tools refuse to write outside the scope" ((last-attempt).reason == "the improver changed nothing")
    check "and refuse to read the eval tasks" ((last-attempt).summary =~ "not readable")

    let r = (improve run shop --improver rogue -n 1)
    check "the loop rejects out-of-scope changes made by other means" ((last-attempt).reason =~ "outside the writable scope")
    check "and removes them" (not ("agent/hack.nu" | path exists))

    # --- an accepted attempt ---
    let r = (improve run shop --improver fixer -n 1)
    let a = (last-attempt)
    check "a change that fixes the tool is accepted" (($a.outcome == "accepted") and ($a.train_score == 1) and ($a.holdout_score == 1))
    check "text with quotes, parentheses and $ survives the tool call" ((open --raw tools_catalog/shop/functions.nu) == $fixed)
    check "it is committed" ((^git log -1 --format=%s) =~ 'self-improve\(shop\): added the missing prices')
    check "the working tree is clean afterwards" ((^git status --porcelain | str trim) == "")
    check "all five attempts are in the archive" ((open --raw improve/archive/shop.jsonl | lines | length) == 5)

    # --- memory ---
    let r = (^$nu.current-exe --no-config-file -c 'use agent/agents.nu [run_named]; run_named echo hi' | complete)
    check "remembered lessons reach the system prompt" ($r.stdout =~ "price list must cover every fruit")

    let r = (improve history shop)
    check "history lists the attempts" ($r.stdout =~ "accepted")

    cd $src
    if $keep { print $"sandbox kept at ($box)" } else { rm -rf $box }
    print "all checks passed"
}
