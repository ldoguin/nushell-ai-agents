# This script parses openapi.json and writes nushell wrapper functions for each endpoint

# Sanitize a string to be used as a Nushell function name
def sanitize_name [text: string] {
  $text | str downcase | str replace -a " " "_" | str replace -r "[^a-z0-9_]" ""
}
# Sanitize a string to be used as a Nushell function name
def sanitize_param_name [text: string] {
  $text | str replace -a "-" "_"
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
          let items = $value.items | merge { description : $value.description }
          return ( manage_properties {key : $key, value : $items}   )
        } else {
          return ( manage_properties   {key : $key, value : $value.items} )
        }
      } else if ( $value.type == 'object' ) {
        return ( "An object containing the following field:" + ( describe-json-schema $value ) + ". This is the last field of the object." )
      } else {
        let typ = $value.type
        let desc = $value.description
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
      $parameters | append  { in : "body", name : "body", required : true, description : $desc , type : "any" } 
    } else {
      $parameters
    }
  )


  let param_builders = ( if ( $parameters | length ) < 1  {
      [] 
  } else {
       ( $parameters | sort-by -r required | each { |x|

        mut queryline = []
        if $x.in == "query" {
          $queryline = $queryline | append $"  if \( $(( sanitize_param_name $x.name)) != null\) {"
          $queryline = $queryline | append $"    $query_params = $query_params | append  { ( sanitize_param_name $x.name) : $( sanitize_param_name $x.name) } "
          $queryline = $queryline | append "  }"
        }
        let queryline = $queryline | str join "\n"

        mut header_params = []
        if $x.in == "header" {
          $header_params = $header_params | append $"  if \( $( sanitize_param_name $x.name) != null\) {"
          $header_params = $header_params | append $"    $header_params = $header_params | append  {  ( sanitize_param_name $x.name) : $( sanitize_param_name $x.name) } "
          $header_params = $header_params | append "  }"
        }
        let header_params = $header_params | str join "\n"



        mut paramline = ["   "]
        # add -- for optional param
        if not ( ( 'required' in  $x ) and ( $x.required == true ) ) {
          $paramline = $paramline | append "--"
        } else {
          #$required_param = $required_param | append $x.name
        }
        let paramline = $paramline | append ( sanitize_param_name $x.name)
        # add type
        let paramline = $paramline | append " : "

        let paramline = $paramline | append " string "

        let paramline = $paramline | append ",  # "
        # add comment
        let paramline = $paramline | append ( $x.description | str replace -a "\n" " ") 
        let paramline = $paramline | str join ""


        let property = [ {
           ( sanitize_param_name $x.name) : {
            type : "any",
            description : ( $x.description | str replace -a "\n" " ") 
          }
        } ]
        

       {queryline : $queryline,  paramline : $paramline, header_params : $header_params, property : $property }
        }  | [ ($in.queryline | filter {|x| $x != "" } | str join "\n"),
            ( $in.paramline | str join "\n ") ,
            ( $in.header_params | filter {|x| $x != "" } | str join "\n ") ,
            ( $in.property )
          ]
        )
    }
  )
 
  mut queryline = ( if ( $param_builders | length ) < 1  { "" } else { $param_builders.0 | filter {|x| $x != "" }  } )
  mut function_params =  ( if ( $param_builders | length ) < 1  { [] } else { $param_builders.1 | filter {|x| $x != "" }  } )
  mut header_params =  ( if ( $param_builders | length ) < 1  { [] } else { $param_builders.2 | filter {|x| $x != "" } } )
  mut properties =  ( if ( $param_builders | length ) < 1  { [] } else { $param_builders.3 | filter {|x| $x != "" } } )

  $header_params = $header_params | prepend "  mut header_params = []\n"
  $queryline = $queryline | prepend "  mut query_params = []\n"

  $function_params = $function_params | str join

  mut lines = [
    $"# ($summary)",
    $"# ($description  | str replace -a '\n' '\n# ' )",
    $"def ($func_name) [\n ($function_params)\n] {",
    $"($header_params | str join )",
    $"($queryline | str join )",
  ]

  if ($request_body == {} ) {
    $lines = $lines | append $"  curl_request  \"($method | str upcase)\" $\"($path)\"  \$query_params  \$header_params  null"
  } else {
    $lines = $lines | append $"  curl_request  \"($method | str upcase)\" $\"($path)\"  \$query_params  \$header_params  \$body"
  }
  $lines = $lines | append "}\n"

  let function = $lines | str join "\n"

  let tool_description = {
    "type": "function",
    "function": {
      "name": $func_name,
      "description":  $description  ,
      "parameters": {
        "type": "object",
        "properties": $properties,
        #"required": $required_param
      }
    }
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
        let tuple = generate_function $path $method $op.summary ( $op.description | str replace -a "\n" "\n# ") (  (  $op.parameters? | default [] ) | append $path_params ) ($op.requestBody? | default {} )
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
  mut lescript = $functions | str join "\n" | str join

  $lescript ++= $curl_file_content

  $lescript | save -f $output_functions_file
  $tools | save -f $output_tools_file
}