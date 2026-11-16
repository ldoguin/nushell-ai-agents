# One-line progress on stderr: what the agent is doing, indented by how deep in
# sub-agent calls it is. Enabled with AGENT_SINKS=console.

def short [] {
    let s = ($in | default "" | into string | str replace --all --regex '\s+' " " | str trim)
    if ($s | str length) > 100 { $"($s | str substring 0..<100)…" } else { $s }
}

export def on-event [event: record] {
    let pad = ("" | fill --width ($event.depth * 2) --character " ")
    let line = (match $event.type {
        "run.start" => $"▶ ($event.agent | default '?')(if ($event.model | is-empty) { '' } else { $' \(($event.model)\)' }) ($event.content?.query? | short)"
        "tool.start" => $"→ ($event.tool) ($event.content?.args? | short)"
        "tool.end" => (if $event.ok { $"← ($event.tool) ok, ($event.duration_ms)ms" } else { $"✗ ($event.tool): ($event.error | short)" })
        "model.end" => (if $event.ok { $"  model: ($event.usage.total_tokens? | default 0) tokens, ($event.duration_ms)ms" } else { $"✗ model call failed: ($event.error | short)" })
        "run.end" => $"◀ ($event.status), ($event.iterations) iteration\(s\), ($event.usage.total_tokens? | default 0) tokens"
        "context.compacted" => $"  context compacted: ($event.elided) tool output\(s\) elided, ~($event.chars_saved) characters saved"
        "budget.exceeded" => $"⛔ budget exceeded: used ($event.used) of ($event.max) \(($event.limit)\)"
        _ => null
    })
    if $line != null {
        print --stderr $"($pad)($line)"
    }
}
