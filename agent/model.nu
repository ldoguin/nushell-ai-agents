use ../common/utils.nu *

# Call local ollama API
export def callama [$model, $messages, $stream, $endpoint, $model_tools, options] {
    let url = $"http://localhost:11434/($endpoint)" 
    let json = {
        model: $model,
        messages: $messages,
        tools: $model_tools,
        stream: $stream,
        options: {
            temperature : 0
        }
        
    };
    let json = $json | merge $options
    $url | log
    $json | log
    let jsonString = ( $json | to json )
    let response = http post  $url  $json
    $response
}

# Call openai api
export def calloai [model, messages, model_tools, options] {
    let url = "https://api.openai.com/v1/chat/completions" 
    let json = {
        model: $model,
        messages: $messages,
        tools: $model_tools
    };
    let json = $json | merge $options
    let jsonString = ( $json | to json )
    let response = ( http post  -e -f $url $json --headers ["Authorization" $"Bearer ($env.OPENAI_API_KEY) " ]   --content-type "application/json")
    $response.body
}
