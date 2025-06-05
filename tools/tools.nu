use ../common/utils.nu *
use cbsh.nu *

# Function Library
export def cbsh_tool_library [] {
    let tools = open "tools/nushell/cbsh-cat-couchbase.json"
    $tools
}

export def tool_library [] {
    let tools = [
        {
            type: 'function',
            function: {
                name: 'calculate',
                description: 'calculate mathematical expressions, can only use numbers directly; cannot call other functions',
                parameters: {
                    type: 'object',
                    properties: {
                        expression: {
                            type: 'string',
                            description: 'The mathematical expression to be evaluated, it can only use numbers',
                        },
                    },
                    required: ['expression'],
                },
            },
        },
    
        {
            type: 'function',
            function: {
                name: 'get_planet_mass',
                description: 'return the mass of a given planet',
                parameters: {
                    type: 'object',
                    properties: {
                        planet: {
                            type: 'string',
                            description: 'The planet name',
                        },
                    },
                    required: ['planet'],
                },
            },
        },
        {
            type: 'function',
            function: {
                name: 'import_git_repo',
                description: 'this function will take a git repository url, clone the repository, extract the commit log, import it with one document per commit in a database, and index all commit in a vector database. If the repository url is not known, it should be search from internet',
                parameters: {
                    type: 'object',
                    properties: {
                        repoPath: {
                            type: 'string',
                            description: 'the url to clone the git repository',
                        },
                        repoName: {
                            type: 'string',
                            description: 'the name of the git repository',
                        },
                    },
                    required: ['repoPath', 'repoName'],
                },
            }
        },
        {
            type: 'function',
            function: {
                name: 'think_code',
                description: 'this function will call a helpful coding agent that has the ability to understand code and choose which tools to use for coding tasks. It can break down code related tasks.',
                parameters: {
                    type: 'object',
                    properties: {
                        prompt: {
                            type: 'string',
                            description: 'the question to anwser',
                        },
                    },
                    required: ['prompt'],
                },
            }
        },
        {
            type: 'function',
            function: {
                name: 'ask_repo',
                description: 'this function will take a git repository that has been already indexed in couchbase, run a vector search and ask a question specialized code agent. The repo must have been imported before this function is used',
                parameters: {
                    type: 'object',
                    properties: {
                        repoName: {
                            type: 'string',
                            description: 'the name of the git repository',
                        },
                        question: {
                            type: 'string',
                            description: 'the question the agent will ask',
                        },
                    },
                    required: ['repoPath', 'repoName'],
                },
            },
        }
        {
            type: 'function',
            function: {
                name: 'search_internet',
                description: 'this function will call the duckduck go search engine, retrieve the top 10 links returned by the search in markdown format.',
                parameters: {
                    type: 'object',
                    properties: {
                        search: {
                            type: 'string',
                            description: 'the search terms to be queried',
                        },
                    },
                    required: ['search'],
                },
            },
        }
    
    ];
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


export def callTool [$toolCall] {
    $toolCall | log
    let functionName = $toolCall.name
    mut arguments = parseArg $toolCall.arguments;
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
            print $q
            let tcResult = ( callTool $tc )
            $responses = ( $responses | append {value : $tcResult} )
            $arguments = ( $arguments |  str replace -r '(?P<fname>\w+)\((?P<arguments>.*?)\)' $tcResult )
        }
        $fInArg = ( $fInArg | merge $responses )
        print $fInArg
    }
    $" source agent.nu; ($functionName)   ($arguments) " | log
    let result_tool = ( cbsh -c ( $" source tools/tools.nu; source cbes.nu; ($functionName)   ($arguments)  " ) ) | complete
    if ( $result_tool.exit_code == 0 ) {
        return $result_tool.stdout
    } else {
        print $result_tool.stderr
        return $result_tool
    }
}
