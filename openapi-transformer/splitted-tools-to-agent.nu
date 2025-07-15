let data = open "splitted_tools.json"

let tuples = $data | each { |x| 
    let name = $x.name | str replace -a " " "_"  | str replace -a "/" "_"  | str replace -a "(" "_" | str replace -a ")" "_"  
    mkdir $name
    $x.functions | to json | save -f $"($name)/tools.json"
    $x.description | to text | save -f $"($name)/prompt.json"
    cp functions.nu $"($name)/functions.nu"

    let tool = {
        "type": "function",
        "function": {
        "name": $name,
        "description": ( "This function calls an ai agent able to do the following :\n" + $x.description ),
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
    let function = $"  def ($name) [query] {\n    let result_tool = \( cbsh -c \( $\" source agent.nu;  agent_run \"($name)\" \"\($query\)\" \"  \)  \) | complete \n    if \( $result_tool.exit_code == 0 \) { \n      return $result_tool.stdout \n    } else {\n      print $result_tool.stderr \n     return $result_tool \n  } \n}"
    [$tool, $function]
}


    mut  tools = []
    mut  functions  = []
    for t in $tuples {
        $tools = $tools | append $t.0
        $functions = $functions | append $t.1
    }

    $functions | to text | save -f ag_functions.nu
    $tools | to json | save -f agent_as_tools.json
