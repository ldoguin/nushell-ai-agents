# Function Library
export def cbsh_tool_library [] {
    let tools = open "tools/nushell/cbsh-cat-couchbase.json"
    $tools
}

export def tool_library [] {
    let tools =  open "tools/tools.json"
    $tools
}

# Arguments reach cbsh through environment variables, never spliced into the
# command string, so a repo name or question cannot inject nu code.
export def ask_repo [options] {
    with-env { ASK_REPO_NAME: $options.repoName, ASK_REPO_QUESTION: $options.question } {
        cbsh -c 'source tools/cbsh.nu; ask_repo $env.ASK_REPO_NAME $env.ASK_REPO_QUESTION'
    }
}

export def import_git_repo [options] {
    with-env { IMPORT_REPO_PATH: $options.repoPath, IMPORT_REPO_NAME: $options.repoName } {
        cbsh -c 'source tools/cbsh.nu; import_git_repo $env.IMPORT_REPO_PATH $env.IMPORT_REPO_NAME'
    }
}

# Evaluate an arithmetic expression. Only digits, whitespace and the
# operators + - * / % ^ x ( ) . are accepted ("x" and "^" are the usual
# written forms of multiply and power), so nothing but arithmetic can reach nu.
export def calculate [options] {
    let expression = ($options.expression | into string)
    if ($expression !~ '^[0-9\s+\-*/%^x().]+$') {
        error make { msg: $"Not an arithmetic expression: ($expression)" }
    }
    let xpr = ($expression | str replace --all 'x' '*' | str replace --all '^' '**')
    ^nu --no-config-file -c $xpr | str trim
}

export def get_planet_mass [options] {
    match ( $options.planet | str lowercase ) {
        "earth" => 5
        "jupiter" => 1.898e27
        "mars" => 6.39e23
        "mercury" => 3.285e23
        "neptune" => 1.024e26
        "saturn" => 5
        "uranus" => 8.681e25
        "venus" => 4.867e24
        _ => 0.0
    }
}

export def search_internet [options] {
    let query = $options.search
    let queryResult = ( ddgr --json -n1 $query |  from json )
    mut answer = []
    for $u in ( $queryResult | enumerate) {
        let url = $u.item.url
        let filename = ( $url | str replace --all 'https://' '' | str replace --all 'http://' '' | str replace --all '/' '_' | str replace --all '.' '_'   )
        
        # need to chunk it and upload/index it to couchbase, sending the search result instead
        # chromium --no-sandbox --headless  --user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.50 Safari/537.36" --dump-dom $url err> /dev/null | html2text | save -f $filename
        #$answer = $answer | append ( open $filename )
        
        $answer = $answer | append $u.item
    }
    $answer
}
