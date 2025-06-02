use ../common/utils.nu *

# Call local ollama API
export def callama [$model, $messages, $stream, $endpoint, $model_tools] {
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
    $url | log
    $json | log
    let jsonString = ( $json | to json )
    print $" ($url) ($jsonString) " 
    let response = http post  $url  $jsonString
    $response
}

# Call openai api
export def calloai [$messages, $model_tools] {
    let url = "https://api.openai.com/v1/chat/completions" 
    let json = {
        model: "gpt-4o-mini",
        messages: $messages,
        tools: $model_tools,
        stream: false,
        temperature: 0
    };
    let jsonString = ( $json | to json )
    let response = http post  $url  $jsonString --headers ["Authorization" $"Bearer ($env.OPENAI_API_KEY) " ]   --content-type "application/json"
    $response
}
