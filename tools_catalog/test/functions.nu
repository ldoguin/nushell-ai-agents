# Stub for the test catalog: pretends to run the named agent.
def agent_runner [options] {
    match $options.name {
        "regis" => "majestic regis"
        "fouf" => "fouf the unfathomable"
        _ => $"no such agent: ($options.name)"
    }
}
