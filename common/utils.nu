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