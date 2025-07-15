let data = open "tools.json"

# Step 1: Collect all unique tags
let unique_tags = open "openapi.json" | reduce --fold []  { |x, acc| ( $acc | append $x.tags ) }  | uniq 

# Step 2: Associate entries with tags
let all_tools = ($unique_tags | each { |tag_entry|
    let functions = ( $data | where {|x| ( $x.tags | any {|t| $t == $tag_entry.name } )})
    let $tag_entry = $tag_entry | merge { functions: $functions }
    $tag_entry
})

let functions = ( $data | where {|x| ( $x.tags? == null or $x.tags? == [] ) } )
let $tag_entry = { functions: $functions }
$tag_entry
#$all_tools | to json | save -f splitted_tools.json
