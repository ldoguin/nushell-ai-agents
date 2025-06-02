# Manage a counter in the "counter" file, increment each time it's called
export def counter [] {
    if  ( not ( "logs/counter" | path exists ) ) {
        0 | save  "logs/counter"
    }
    mut count = open "logs/counter" | into int
    $count = $count + 1
    $count | save -f "logs/counter"
    $count
}

# generate a unique filename based on the counter and a random uuid
export def new_logfile [] {
    let c = counter
    $"($c)-(random uuid)"
}

# Log the input in the "myHistory" file
export def log [] {
    let s = $in
    "\n" | save -a  "logs/myHistory"
    if ( (  ($s | (describe ) ) != "nothing" ) and ( $s != "" ) ) {
        $s | to text|  save -a "logs/myHistory"  
    }
    
}

# Return true if the input data contains a column of the given parameter
export def column_exist [$column_name] {
    let exist = $in | columns | any {|| $in  == $column_name }
    $exist
}

# Requires the nushell notification plugin
# Will send a notification when the give closure is completed.
export def notifyOnDone [ task: closure] {
    let start = date now
    let result = do $task
    let end = date now
    let total = $end - $start | format duration sec
    let body = $"given task finished in ($total)"
    notify -s "task is done" -t $body
    return $result
}