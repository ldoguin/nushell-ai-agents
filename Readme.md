# Nushell Agents

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/ldoguin/nushell-ai-agents)
[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/ldoguin/nushell-ai-agents)

This repository contains an example of Ai agents built with Nushell.

```nushell
cbsh
source agent.nu
run "who are the contibutors of the github project couchbaselabs/couchbase-shell "
```

## Dependencies

### Nushell

The only mandatory dependency is [Nushell](https://nushell.sh). Everything else will just be tools and models configuration. You can also use Couchbase Shell as a replacement, which is also needed for some of the available tools. 

#### Nushell Plugin

##### nu_plugin_audio_hook

Install [nu_plugin_audio_hook](https://github.com/FMotalleb/nu_plugin_audio_hook) to get sounds notification at the end of an agent request.

### Models

#### OpenAi

OpenAI Agents will work as long as you have set your OpenAi API key.

`export OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxx`

#### Anthropic

Set `"runtime": "anthropic"` in an agent's `agents.json` entry (e.g.
`"model": "claude-opus-4-5"`) and export your API key:

`export ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxx`

Tool-calling (`model_tools`/`tool_functions`) works the same way it does
for the `openai` runtime -- `agent/model.nu`'s `call_anthropic` translates
this repo's OpenAI-shaped messages/tools/response to and from Anthropic's
Messages API shape, so `agent/agents.nu` and `agent/internal.nu` need no
runtime-specific handling.

Anthropic-specific request options (e.g. extended thinking --
`{ "thinking": { "type": "enabled", "budget_tokens": 8000 } }`) can be set
directly in the agent's `options` in `agents.json`; note Anthropic
requires `max_tokens` to exceed `thinking.budget_tokens` and rejects
`temperature` alongside `thinking`.

#### Amazon Bedrock

Set `"runtime": "bedrock"` in an agent's `agents.json` entry, with `"model"`
set to a Bedrock model ID or cross-region inference profile ID -- on-demand/
"serverless" usage of Anthropic's newer models on Bedrock requires the
inference-profile form, not the bare model ID. The same Claude models this
repo's `anthropic` runtime uses are available on Bedrock too, e.g. (verified
live against a `us-west-2` account):

- `us.anthropic.claude-haiku-4-5-20251001-v1:0`
- `us.anthropic.claude-sonnet-4-5-20250929-v1:0`
- `us.anthropic.claude-opus-4-5-20251101-v1:0`

Export a
[Bedrock API key](https://docs.aws.amazon.com/bedrock/latest/userguide/api-keys.html)
(a bearer token generated in the Bedrock console) plus the region it's
scoped to (`AWS_DEFAULT_REGION`, the AWS CLI/SDKs' own standard var, works
too -- `AWS_REGION` just takes precedence when both are set):

```sh
export AWS_BEARER_TOKEN_BEDROCK=bedrock-api-key-xxxxxxxxxxxxxxxxxxxx
export AWS_REGION=us-east-1
```

This avoids IAM SigV4 request signing entirely -- `agent/model.nu`'s
`call_bedrock` is a plain HTTPS call to Bedrock's Converse API with an
`Authorization: Bearer` header, shaped like `call_anthropic`/`calloai`
rather than needing the AWS CLI or an AWS SDK. Converse is
provider-agnostic across every model Bedrock hosts, so tool-calling
(`model_tools`/`tool_functions`) works the same way it does for the other
runtimes -- `call_bedrock` translates this repo's OpenAI-shaped
messages/tools/response convention to and from Converse's shape, so
`agent/agents.nu` and `agent/internal.nu` need no runtime-specific
handling.

#### Ollama

Follow their documentation on [https://github.com/ollama/ollama/blob/main/README.md#quickstart](https://github.com/ollama/ollama/blob/main/README.md#quickstart)

Make sure you have pulled models used by your agents first, and that your server is running on _localhost:11434_.

### Observability (OpenTelemetry)

`agent/common/otel.nu` sends real OTLP/HTTP+protobuf traces -- one span per
model call (`gen_ai.chat`, with token usage), one per agent run/iteration
(`agent.run`/`agent.iteration`), and one per tool call (`execute_tool
<name>`, per [OpenTelemetry's GenAI semantic
conventions](https://github.com/open-telemetry/semantic-conventions-genai)).
Off by default in the sense that a down/unreachable collector never blocks
or fails a real call -- point it at a real one to actually see anything:

```sh
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318  # default if unset
export OTEL_EXPORTER_OTLP_HEADERS=x-api-key=abc,x-team=obs # optional, "k=v,k2=v2"
export OTEL_SERVICE_NAME=authoring-pipeline                # default if unset
```

Tool call arguments/results (`gen_ai.tool.call.arguments`/
`gen_ai.tool.call.result`) are opt-in, since the semantic conventions flag
both as possibly sensitive:

```sh
export OTEL_CAPTURE_TOOL_CONTENT=true
```

Each `gen_ai.chat` span also emits three GenAI metrics (OTLP/HTTP+protobuf to
`<endpoint>/v1/metrics`) as OTel's required Histogram instrument type:
`gen_ai.client.token.usage` (once per token type, `gen_ai.token.type` =
`input`/`output`) and `gen_ai.client.operation.duration` (seconds), all
tagged with `gen_ai.operation.name`/`gen_ai.provider.name`/
`gen_ai.request.model`. A `retry_count` attribute (from each provider
function's own retry loop) rides on the span alongside the existing token
counts. If the underlying model call fails after exhausting its retries, the
span is still ended (status ERROR, `error.type`) instead of being silently
dropped -- the original error still propagates to the caller unchanged.

When run inside GitHub Actions, every span's resource picks up
`cicd.pipeline.name`/`cicd.pipeline.run.id`/`cicd.pipeline.run.url.full`/
`vcs.repository.name`/`vcs.ref.head.name` automatically from the standard
`GITHUB_*` environment variables Actions itself sets -- no configuration
needed, and these stay absent for local runs.

A model call or tool call that fails records a standard OTel `exception`
span event (`exception.type`/`exception.message`), in addition to marking
the span ERROR -- both the event (the specific failure) and the
error-status attribute (so a failed span can be filtered without
inspecting events) are populated, per OTel's own general span conventions.

Two counters (OTLP Sum metrics, monotonic) round out the metrics:
`agent.tool.call.count` (tagged `gen_ai.tool.name`/`status`) and
`agent.iteration.count` (one increment per `agent.run`, valued at the
total iterations taken), for graphing call/iteration volume directly
instead of deriving it from span counts.

`engine.nu`'s `run-pipeline-agent` chains every `pipeline.agent:*` span --
across rounds within a step and across steps in the same job -- into one
linear parent/child sequence (`logs/.otel-parent-span-id`, alongside the
existing `logs/.otel-trace-id`), rather than each being an unrelated
root-level span that only shares a trace ID.

Verified live against both [otel-desktop-viewer](https://github.com/CtrlSpice/otel-desktop-viewer)
(a local dev collector) and Arize Phoenix (a real external one, protobuf-only).

### Tools

#### Couchbase Shell

[Couchbase Shell](https://couchbase.sh) will be used to store data, expecially vectors, so that you can easily run Vector Search. Its configuration must allow you to create buckets, scopes, collections and indexes.

#### DDGR

The search tool relies on [DDGR](https://github.com/jarun/ddgr?tab=readme-ov-file#installation).

## Slides

Slides are displayed using [presenterm](https://github.com/mfontanini/presenterm).

```
cd slides
presenterm -x couchbase.md  # -x flag enables code execution from the slides, hit ctrl-e to run code during the presentation. 
```

### Enabling slide nushell hightlighting

Installing presenterm from source is mandatory for this.

Nushell code highlighting is not available by default. To build it, place [the synthax file](https://github.com/kurokirasama/nushell_sublime_syntax/blob/main/nushell.sublime-syntax) in your bat config folder and rebuild it. Then copy and paste the synthax file in your local presenterm installation and rebuild it.
