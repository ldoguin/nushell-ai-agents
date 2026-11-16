# Finding agents: one manifest (an agents.json: { "<name>": <config entry> }),
# loaded explicitly instead of the old "merge every agents.json under the
# current directory" glob, which made which agent you got depend on where you
# stood. Relative paths in an entry resolve against the manifest's directory.
use agents.nu [agent]

const REPO_ROOT = (path self ..)

# Which manifest: the argument, else $env.AGENTS_FILE, else the repo's own agents.json.
export def manifest-path [path?: string] {
    let chosen = ($path | default ($env.AGENTS_FILE? | default ($REPO_ROOT | path join agents.json)))
    let full = ($chosen | path expand)
    if not ($full | path exists) {
        error make { msg: $"Agents manifest not found: ($full)" }
    }
    $full
}

# Read a manifest: { path, dir, agents: { name: raw config entry } }.
export def load-manifest [path?: string] {
    let file = (manifest-path $path)
    let agents = (try { open $file } catch {|e| error make { msg: $"($file) is not valid JSON: ($e.msg)" } })
    if ($agents | describe | str starts-with "record") == false {
        error make { msg: $"($file) must be a JSON object mapping agent names to configs" }
    }
    { path: $file, dir: ($file | path dirname), agents: $agents }
}

# The agents a manifest defines.
export def list-agents [--manifest (-m): string] {
    let m = (load-manifest $manifest)
    $m.agents | transpose name config | each {|a|
        {
            name: $a.name
            runtime: ($a.config.runtime? | default "")
            model: ($a.config.model? | default "")
            description: ($a.config.description? | default "")
            agents: ($a.config.agents? | default [])
        }
    }
}

# The agent names a config entry lists in `agents`. A malformed value is treated
# as none here -- agent/config.nu reports it, naming the agent, when it is built.
def sub-names [config: record] {
    let listed = ($config | get -o agents | default [])
    if ($listed | describe | str starts-with "list") { $listed } else { [] }
}

# Walk the agents reachable from `name` through their `agents` lists, and fail
# on a name that does not exist or a cycle (a -> b -> a would recurse forever).
# Returns every reachable agent name, `name` first.
def reachable [agents: record, name: string, path: list<string>] {
    if $name in $path {
        let loop = ($path | skip until {|n| $n == $name } | append $name | str join " -> ")
        error make { msg: $"Agent cycle: ($loop). An agent cannot be offered, directly or indirectly, to itself." }
    }
    let config = ($agents | get -o $name | default null)
    if $config == null {
        let from = ($path | last | default "")
        error make { msg: $"Agent '($from)' lists agent '($name)' in 'agents', but the manifest has no such agent. Available: ($agents | columns | str join ', ')" }
    }
    let children = (sub-names $config)
    mut seen = [$name]
    for child in $children {
        $seen = ($seen | append (reachable $agents $child ($path | append $name)) | uniq)
    }
    $seen
}

# Build one manifest entry. Its sub-agents are described to it (name ->
# description) so their tools can be shown to the model.
def build [m: record, name: string] {
    let config = ($m.agents | get $name)
    let children = (sub-names $config)
    let subagents = ($children | reduce --fold {} {|c, acc|
        $acc | upsert $c { description: ($m.agents | get $c | get -o description | default "") }
    })
    agent $config --name $name --base-dir $m.dir --subagents $subagents --manifest-path $m.path
}

# Build one agent by name. Validates it -- and every agent it can reach through
# `agents` -- here, so a bad config, an unknown sub-agent or a cycle is
# reported on load rather than in the middle of a run.
export def get-agent [name: string, --manifest (-m): string] {
    let m = (load-manifest $manifest)
    if ($m.agents | get -o $name | default null) == null {
        error make { msg: $"No agent named '($name)' in ($m.path). Available: ($m.agents | columns | str join ', ')" }
    }
    for n in (reachable $m.agents $name []) {
        build $m $n
    }
    build $m $name
}
