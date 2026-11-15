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
        { name: $a.name, runtime: ($a.config.runtime? | default ""), model: ($a.config.model? | default ""), description: ($a.config.description? | default "") }
    }
}

# Build one agent by name. Validates it (and so reports config errors) here.
export def get-agent [name: string, --manifest (-m): string] {
    let m = (load-manifest $manifest)
    let config = ($m.agents | get -o $name | default null)
    if $config == null {
        error make { msg: $"No agent named '($name)' in ($m.path). Available: ($m.agents | columns | str join ', ')" }
    }
    agent $config --name $name --base-dir $m.dir
}
