# This script parses openapi.json and writes nushell wrapper functions for each endpoint

# Sanitize a string to be used as a Nushell function name
def sanitize_name [text: string] {
  $text | str downcase | str replace -a " " "_" | str replace -r "[^a-z0-9_]" ""
}
# Sanitize a string to be used as a Nushell function name
def sanitize_param_name [text: string] {
  $text | str replace -a "-" "_"
}

def match-oai-type [param] {
  if ($param.type? != null) {
    return ( $param | reject -i name required in )
  } else {
    return ( match-oai-type $param.schema )
  }
}

def manage_properties [props : any] {
      let key = $props.key
      mut value = $props.value

      if ($value.oneOf? !=  null ) {
       return ( $value.oneOf | each { |x|
         describe-json-schema $x
        } | str join "." )
        
      } else if ($value.allOf? !=  null ) {
        return ( $value.allOf | each { |x|
         describe-json-schema $x
        } | str join "." )

      } else if ( $value.type == 'array' ) {
        if ($value.items.description? == null ) {
          let desc = $value.description?
          let items = $value.items | merge { description : $desc }
          return ( manage_properties {key : $key, value : $items}   )
        } else {
          return ( manage_properties   {key : $key, value : $value.items} )
        }
      } else if ( $value.type == 'object' ) {
        return ( "An object containing the following field:" + ( describe-json-schema $value ) + ". This is the last field of the object." )
      } else {
        let typ = $value.type
        mut desc = $value.description?
        return $"($key) ($typ) - ($desc)"
      }
      
}

def describe-json-schema [json: record] {
  if ($json.properties? == null ) {
    return ""
  }
  let props = $json.properties
  return ( $props
  | transpose key value | each { |it|
      manage_properties $it
    }
  | str join ". " )
}

# Generate a Nushell function block for each method of each path
def generate_function [
    path: string
    method: string
    summary: string
    description: string
    parameters: list
    request_body: record
    tags: list
] {
  
  let path = $path | str replace -a -r '\{' "($"
  let path = $path | str replace -a  '}' ')'
  let clean_name = sanitize_name $summary
  let func_name = $"($method)_($clean_name)"
  
  # Replace null by false when value is empty
  let parameters = $parameters | each { |x| 
    mut tmp = $x
    if not ('required' in $x ) {
      $tmp.required = false
    }
    $tmp
  } 

  let $parameters = ( if ($request_body != {} ) {
      let desc = describe-json-schema ( $request_body.content | values | $in.0.schema )
      $parameters | append  { in : "body", name : "body", required : true, description : ( $request_body.content | to text ) , type : "string" } 
    } else {
      $parameters
    }
  )
 let $parameters  = $parameters | sort-by required

  let param_builders = ( if ( $parameters | length ) < 1  {
      [] 
  } else {
       ( $parameters | each { |x|

        mut queryline = []
        if $x.in == "query" {
          $queryline = $queryline | append $"  if \( \( $tool_args | get -i ($x.name) \) != null \) {"
          $queryline = $queryline | append $"    $query_params = $query_params | append  { ( $x.name) : \( $tool_args | get ($x.name) \) } "
          $queryline = $queryline | append "  }"
        }
        let queryline = $queryline | str join "\n"

        mut header_params = []
        if $x.in == "header" {
          $header_params = $header_params | append $"  if \( \( $tool_args | get -i ($x.name) \) != null \) {"
          $header_params = $header_params | append $"    $header_params = $header_params | append  { ( $x.name) : \( $tool_args | get ($x.name) \) } "
          $header_params = $header_params | append "  }"
        }
        let header_params = $header_params | str join "\n"

        mut path_params = []
        if $x.in == "path" {
          $path_params = $path_params | append $"  let  ( $x.name) =  \( $tool_args | get ($x.name) \) "
        }
        let path_params = $path_params | str join "\n"

        mut required_param = ""
        mut paramline = ["   "]
        $paramline = $paramline | append ( sanitize_param_name $x.name)
        # add ? for optional param
        if not ( ( 'required' in  $x ) and ( $x.required == true ) ) {
          $paramline = $paramline | append "?"
        } else {
          $required_param =  $x.name
        }
        

        # add comment
        let paramline = $paramline | append ",  # "
        let paramline = $paramline | append ( $x.description | str replace -a "\n" " ") 
        let paramline = $paramline | str join ""

        mut t = match-oai-type $x
        $t  = $t | merge  { description : ( $x.description | str replace -a "\n" " ") }

        mut property = {
           ( sanitize_param_name $x.name) : $t
        } 

        
       {queryline : $queryline,  paramline : $paramline, header_params : $header_params, property :  $property  , required_param : $required_param, path_params : $path_params }
        }  | [ ($in.queryline | filter {|x| $x != "" } | str join "\n"),
            ( $in.paramline | str join "\n ") ,
            ( $in.header_params | filter {|x| $x != "" } | str join "\n ") ,
            ( $in.property ),
            ( $in.required_param ),
            ( $in.path_params | filter {|x| $x != "" } | str join "\n " )
          ]
        )
    }
  )
 
  mut queryline = ( if ( $param_builders | length ) < 1  { "" } else { $param_builders.0 | filter {|x| $x != "" }  } )
  mut function_params =  ( if ( $param_builders | length ) < 1  { [] } else { $param_builders.1 | filter {|x| $x != "" }  } )
  mut header_params =  ( if ( $param_builders | length ) < 1  { [] } else { $param_builders.2 | filter {|x| $x != "" } } )
  mut properties =  ( if ( $param_builders | length ) < 1  { [] } else { $param_builders.3 | filter {|x| $x != "" } } )
  mut required_params =  ( if ( $param_builders | length ) < 1  { [] } else { $param_builders.4 | filter {|x| $x != "" }  } )
  mut path_params =  ( if ( $param_builders | length ) < 1  { [] } else { $param_builders.5 | filter {|x| $x != "" }  } )

  $header_params = $header_params | prepend "  mut header_params = []\n"
  $queryline = $queryline | prepend "  mut query_params = []\n"

  $function_params = $function_params | str join

  mut lines = [
    $"# ($summary)",
    $"# ($description  | str replace -a '\n' '\n# ' )",
    #$"def ($func_name) [\n ($function_params)\n] {",
    $"def ($func_name) [\n tool_args \n] {",
    $"($header_params | str join )",
    $"($queryline | str join )",
    $"($path_params | str join )",
  ]

  if ($request_body == {} ) {
    $lines = $lines | append $"  curl_request  \"($method | str upcase)\" $\"($path)\"  \$query_params  \$header_params  null"
  } else {
    $lines = $lines | append $"  $header_params = $header_params | append  { "Content-Type" :  "application/json"} "
    $lines = $lines | append $"  let \$body = \( $tool_args | get body \)"
    $lines = $lines | append $"  curl_request  \"($method | str upcase)\" $\"($path)\"  \$query_params  \$header_params  \$body"
  }
  $lines = $lines | append "}\n"

  let function = $lines | str join "\n"

  mut tool_function =  {
      "name": $func_name,
      "description":  $description 
    }

    if ( ($properties | length) > 0 ) {
     $tool_function = $tool_function | merge { "parameters": {
        "type": "object",
        "properties": ( $properties | reduce --fold {} {|acc, item| $acc | merge $item } ),
        "required": $required_params
        }
      }
  }
      

  let tool_description = {
    "type": "function",
    "tags": $tags,
    "function": $tool_function
  }

  [$function, $tool_description]
}

# Generate all functions and write to file
def main [
    openapi_file: string = "openapi_inlined.json"
    curl_request_file: string = "curl_request.nu"
    output_functions_file: string = "functions.nu"
    output_tools_file: string = "tools.json"
] {
    mut tuples =  ( open $openapi_file | get paths | transpose key value | each { |it|

    let path = $it.key
    let methods_params = $it.value
    let path_params = $methods_params.parameters?

    let methods = ( $methods_params | reject -i parameters )
    $methods | transpose key value | each { |m|
        let method = $m.key
        let op = $m.value
        let tuple = generate_function $path $method $op.summary ( $op.description | str replace -a "\n" "\n# ") (  (  $op.parameters? | default [] ) | append $path_params ) ($op.requestBody? | default {} ) ($op.tags? | default [] )
        $tuple
     }
    }
  )

  mut functions = $tuples | flatten | each { |x|
    $x.0
  }

  mut tools = $tuples | flatten | each { |x|
    $x.1
  }

  let curl_file_content = open $curl_request_file
  mut full_script = $functions | str join "\n" | str join

  $full_script ++= $curl_file_content

  $full_script | save -f $output_functions_file
  $tools | save -f $output_tools_file
}