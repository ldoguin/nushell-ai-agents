# Generic JSON transformer using a closure
def transform-json [data: any, transform: closure] {
    let ty = ($data | describe -d | get type)
    match $ty {
        record => (
            $data
            | transpose key value
            | each { |x| if ( $x.key ==  "$ref" ) {
                    transform-json $x.value $transform
                } else {
                    { $x.key: ( transform-json $x.value $transform ) }
                }
            }
            | reduce --fold {} { |item, acc| print $item; ( $acc | merge $item ) }
        )
        list => (
            $data | each { |item| transform-json $item $transform }
        )
        _ => { do $transform $data }
    }
}


# Helper to resolve $field strings
def resolve-field [field, components] {
    let key = $field.key
    let value = $field.value
    print $key
    if $key == "$ref" {
        if ($value | describe) == 'string' and ($value | str starts-with "#/components/") {
            let parts = ($value | str replace "#/components/" "" | split row "/")
            let comp_type = $parts.0
            let comp_name = $parts.1
            $components | get $comp_type | get $comp_name
        } else if ($value | describe) == 'string' and ($value | str starts-with "#/paths/") {
            let parts = $value | str replace "#/paths/" "" | split row '/' | str replace -a "~1" "/" | str replace -a "%7B" "{" | str replace -a "%7D" "}" 
            find-by-path $parts
        }
    }
    {$key : $value}
}

# Helper to resolve $field strings
def resolve-ref [field, components] {
    if ($field | describe) == 'string' and ($field | str starts-with "#/components/") {
        let parts = ($field | str replace "#/components/" "" | split row "/")
        let comp_type = $parts.0
        let comp_name = $parts.1
        $components | get $comp_type | get $comp_name
    } else if ($field | describe) == 'string' and ($field | str starts-with "#/paths/") {
        let parts = $field | str replace "#/paths/" "" | split row '/' | str replace -a "~1" "/" | str replace -a "%7B" "{" | str replace -a "%7D" "}" 
        find-by-path $parts        
    } else {
        $field
    }
}

def find-by-path [ parts ] {
    let paths = ( open $env.OPENAPI_PATH ).paths
    $parts | reduce --fold $paths { |x, acc|  ( $acc | get $x )  }
}

# Generate all functions and write to file
def main [
    openapi_file: string = "openapi.json"
    output_file: string = "openapi_inlined.json"
] {
    $env.OPENAPI_PATH = $openapi_file
    # Load and process
    let data = open $openapi_file
    let components = $data.components

    # First pass: resolve $ref strings in components
    let components2 = transform-json $components {|x|
        resolve-ref $x $components
    }

    # Second pass: deeper resolution
    let components3 = transform-json $components2 {|x|
        resolve-ref $x $components2
    }

    # Final transformation of full data
    let components4 = transform-json $components3 {|x|
        resolve-ref $x $components3
    }

    # Final transformation of full data
    let resolved = transform-json $data {|x|
        resolve-ref $x $components4
    }
    # Save cleaned data without `components`
    $resolved | reject components | to json | save -f $output_file
    $"✅ Saved Nushell wrappers to: ($output_file)"
}

