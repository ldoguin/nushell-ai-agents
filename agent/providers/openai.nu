# OpenAI's Chat Completions API -- and anything that speaks it (LiteLLM, vLLM,
# Azure's /openai/v1, ...). The repo's canonical message format IS this API's,
# so there is no translation: only transport, errors and usage.
#
# OPENAI_BASE_URL (optional) follows the OpenAI SDKs' convention of including
# the version segment, e.g. http://litellm:4000/v1. Unset: api.openai.com.
use ../http.nu *

export def call [model: string, messages: list, model_tools: list, options: record] {
    require-env OPENAI_API_KEY "OpenAI"
    let base = (provider-base-url "OPENAI_BASE_URL" "https://api.openai.com/v1")
    # The API rejects `tools: []`, so only send tools when there are some.
    let body = ({ model: $model, messages: $messages }
        | merge (if ($model_tools | is-empty) { {} } else { { tools: $model_tools } })
        | merge $options)

    call-provider {
        name: "OpenAI"
        url: $"($base)/chat/completions"
        headers: ["Authorization" $"Bearer ($env.OPENAI_API_KEY)"]
        body: $body
        # OpenAI's error body is { error: { message, type, code } } with no
        # top-level "type": "error" marker, so go by the HTTP status.
        check: {|r|
            if $r.status >= 300 {
                api-error "OpenAI" $r ($r.body | get -o error.message | default "unknown error")
            }
        }
        parse: {|r| $r.body | upsert usage ($r.body | get -o usage | default { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 }) }
    }
}
