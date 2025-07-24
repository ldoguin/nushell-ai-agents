let data = open "splitted_tools.json"

let tuples = $data | each { |x| 
    let name = $x.name | str replace -a --regex " |-|&|'|,|\"|\\(|\\)|/"  '_'
    mkdir $name
    $x.functions | to json | save -f $"(pwd)/($name)/tools.json"
    $x.description | to text | save -f $"(pwd)/($name)/prompt.txt"
    cp functions.nu $"(pwd)/($name)/functions.nu"
    let description =  ( "This function calls an ai agent able to do the following :\n" + $x.description )
    let tool = {
        "type": "function",
        "function": {
        "name": $name,
        "description": $description,
        "parameters": {
            "type": "object",
            "properties": {
            "prompt": {
                "type": "string",
                "description": "the agent prompt"
            }
            },
            "required": [
            "prompt"
            ]
        }
        }
    }
    let agent = { $name : {
        "runtime" : "openai",
        "model":"gpt-4o-mini",
        "prompt": $"(pwd)/($name)/prompt.txt"
        "model_tools": $"(pwd)/($name)/tools.json",
        "tool_functions": $"(pwd)/($name)/functions.nu",
        "description": $description,
        "options" : {
            "stream": false,
            "temperature": 0
            }
       }
    }
    let function = $"  def ($name) [query] {\n    let result_tool = \( cbsh -c \( $\" source agent.nu;  agent_run \"($name)\" \"\($query\)\" \"  \)  \) | complete \n    if \( $result_tool.exit_code == 0 \) { \n      return $result_tool.stdout \n    } else {\n      print $result_tool.stderr \n     return $result_tool \n  } \n}"
    [$tool, $function, $agent]
}


mut  tools = []
mut  functions  = []
mut  agents  = {}
for t in $tuples {
    $tools = $tools | append $t.0
    $functions = $functions | append $t.1
    $agents = $agents | merge $t.2
}

$functions | to text | save -f ag_functions.nu
$tools | to json | save -f agent_as_tools.json
$agents | to json | save -f agents.json
