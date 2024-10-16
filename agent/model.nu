use ../tools/tools.nu [tool_library]
use ../common/utils.nu *

# Call local ollama API
export def callama [$model, $messages, $stream, $endpoint] {
    let model_tools = tool_library
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
    let response = curl  $"($url)" -d $jsonString
    print $response | log
    $response | from json
}

# Call openai api
export def calloai [$messages] {
    let model_tools = tool_library
    let url = "https://api.openai.com/v1/chat/completions" 
    let json = {
        model: "gpt-4o-mini",
        messages: $messages,
        tools: $model_tools,
        stream: false,
        temperature: 0
    };
    let jsonString = ( $json | to json )
    let response = curl   -H "Content-Type: application/json" -H $"Authorization: Bearer ($env.OPENAI_API_KEY) "  -s $"($url)" -d $jsonString
    $response | from json
}
