# Nushell param types -> help commands | select params.type | flatten | uniq

# Supported tool types
# String
# Number
# Boolean
# Integer
# Object
# Array
# Enum
# anyOf

# switch (or flag) will be treated as boolean as "There is no way to have a parameter that is a "flag" purely by its presence (like a CLI flag without a value). In OpenAI’s schema, all arguments must have a type and value, so for flags, boolean is the most appropriate."

def type_map [] {
    match $in {
        "cell-path" | "path" | "duration" => "string"
        "number"  => "number"
        "bool"  => "boolean"
        "int"  => "integer"
        "record" | "purple" => "object"
        "list<any>" | "list<float>" | "list<string>" => "array"
        "yellow" | "purple" => "enum"
        "any" | "purple" => "anyof"
        "switch" => "boolean"
        _ => "anyof"
      }
}

def main [] {
    let commands = help commands | where category == 'couchbase'
    mut tools = []
    for x in $commands {
        #print $x
        #print $x.params
        #print $x.input_output
        let params = []
        
        mut parameters =  {
            type: 'object',
            properties: { },
            required: [],
        };
        for p in $x.params {
            if ($p.required) {
                $parameters.required = ( $parameters.required | append $p.name )
            }
            if ($p.name != "--help(-h)") {
                let parsedName = ( $p.name | parse --regex '^(--.*)\(.*'  )
                mut name = ""
                if (  $parsedName == [] ) {
                    # Regular param
                    $name = $p.name
                } else {
                     # optional param
                     $name = $parsedName.0.capture0
                }
                let mappedType = ( $p.type | type_map )
                mut description = ""
                if ( $p.type == "switch" ) {
                    $description = $"This paramater must be used as flag. ($p.description)"
                } else {
                    $description = $p.description
                }
                
                let prop = { $name: {
                    type: $mappedType,
                    description: $description,
                    }   
                }
                
                $parameters.properties = ( $parameters.properties | merge $prop )

            }
        
        }  
        let t =   {
                type: 'function',
                function: {
                    name: $x.name,
                    description: $x.description,
                    parameters:$parameters
            }
        }
        $tools = ( $tools | append $t )
    }
    $tools | save -f cbsh-cat-couchbase.json
}


