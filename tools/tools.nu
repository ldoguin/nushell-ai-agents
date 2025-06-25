use ../common/utils.nu *
use cbsh.nu *

# Function Library
export def cbsh_tool_library [] {
    let tools = open "tools/nushell/cbsh-cat-couchbase.json"
    $tools
}

export def tool_library [] {
    let tools =  open "tools/tools.json"
    $tools
}

export def ask_repo [repoName, question] {
    let r = cbsh -c $"source tools/cbsh.nu; ask_repo \"($repoName)\" \"($question)\" "
    $r
}

export def import_git_repo [repoPath : string, repoName : string ] {
    let r =  cbsh -c $"source tools/cbsh.nu; import_git_repo \"($repoPath)\" \"($repoName)\" "
    $r
}

export def calculate [$op] {
    let xpr = ( $op | str replace --all -r 'x' '*' ) 
    let x: string = nu -c $xpr
    $x
}

export def get_planet_mass [$planet] {
    match ( $planet | str downcase ) {
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

export def search_internet [query] {
    print $query
    let queryResult = ( ddgr --json -n1 $query |  from json )
    print $queryResult
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


export def callTool [$toolCall, tool_functions] {
    $toolCall | log
    let functionName = $toolCall.name
     #mut arguments = parseArg $toolCall.arguments 
    mut arguments =  $toolCall.arguments 
    $arguments | log
    mut fInArg = ( $arguments | parse --regex '(?P<fname>\w+)\((?P<arguments>.*?)\)' )
    if ( $fInArg != [] ) {
        mut responses = []
        for $fun in ( $fInArg | enumerate) {
            let tc = {
                name : $fun.item.fname,
                arguments: { "args" : ( $fun.item.arguments | split row , ) }
            }
            print " $tc.arguments"
            let q = ( $tc.arguments.args | str replace -r '^"' '' | str replace -r '"$' '' ) 
            let tcResult = ( callTool $tc $tool_functions )
            $responses = ( $responses | append {value : $tcResult} )
            $arguments = ( $arguments |  str replace -r '(?P<fname>\w+)\((?P<arguments>.*?)\)' $tcResult )
        }
        $fInArg = ( $fInArg | merge $responses )
        print $fInArg
    }
    $" source ($tool_functions); ($functionName)   ($arguments)  " | log
    let result_tool = ( cbsh -c ( $" source ($tool_functions);  ($functionName) ($arguments ) "  )  ) | complete
    if ( $result_tool.exit_code == 0 ) {
        return $result_tool.stdout
    } else {
        print $result_tool.stderr
        return $result_tool
    }
}
