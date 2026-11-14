#!/usr/bin/env nu
# Test runner: every `export def test-*` in tests/test_*.nu is one test, run in
# its own nu process (fresh state, and its own scratch cwd so logs/ never lands
# in the repo). Exit status is non-zero if any test fails.
#
#   nu tests/run.nu                 # everything
#   nu tests/run.nu --filter retry  # only tests whose name contains "retry"

def main [--filter: string = ""] {
    let root = ($env.FILE_PWD | path dirname)
    let nu_bin = (which nu | get 0.path)

    let tests = (glob $"($root)/tests/test_*.nu" | sort | each {|file|
        let names = (^$nu_bin --no-config-file -c $"use '($file)' *; scope commands | where name starts-with 'test-' and type == 'custom' | get name | to json --raw" | from json)
        $names | each {|n| { file: $file, name: $n } }
    } | flatten | where {|t| $t.name | str contains $filter })

    let results = ($tests | par-each --keep-order {|t|
        let scratch = (mktemp --directory)
        let started = (date now)
        let out = (do { cd $scratch; ^$nu_bin --no-config-file -c $"use '($t.file)' *; ($t.name)" } | complete)
        rm --recursive --force $scratch
        $t | insert ok ($out.exit_code == 0) | insert output ($out.stdout + $out.stderr | str trim) | insert took ((date now) - $started)
    })

    for r in $results {
        let mark = (if $r.ok { "PASS" } else { "FAIL" })
        print $"($mark)  ($r.file | path basename | str replace '.nu' ''): ($r.name)  \(($r.took)\)"
        if not $r.ok { print ($r.output | lines | each {|l| $"    ($l)" } | str join "\n") }
    }
    let failed = ($results | where ok == false | length)
    print $"\n($results | length) tests, ($failed) failed"
    if $failed > 0 { exit 1 }
}
