# Nushell Agents

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/ldoguin/nushell-ai-agents)
[![Open in Gitpod](https://gitpod.io/button/open-in-gitpod.svg)](https://gitpod.io/#https://github.com/ldoguin/nushell-ai-agents)

This repository contains an example of Ai agents built with Nushell.

```nushell
# from a shell
nu agent.nu "who are the contributors of couchbaselabs/couchbase-shell?" --agent general_oai

# from nu
use agent.nu *
agent-list                                    # the agents in agents.json
agent-ask "summarize this" --agent writer     # returns the answer
"some text" | agent-ask "summarize:" -a writer
agent-ask "..." -a writer --full              # the whole result record
```

## How it fits together

- **`agents.json`** (or `--manifest` / `$env.AGENTS_FILE`) maps agent names to
  config entries: runtime, model, prompt, tools, limits. Entries are validated
  when loaded (`agent/config.nu` lists every key) and relative paths resolve
  against the manifest's directory, so it works from any directory.
- **`agent/loop.nu`'s `run-agent`** runs the loop and always returns a record:
  `status` (`done`, `truncated`, `max_turns`, `budget_exceeded` or `error`), `answer`, `error`,
  the whole `messages` conversation, summed `usage` and the `iterations` used.
  Pass the returned `messages` into a new agent record to continue a
  conversation. The last permitted iteration asks the model to answer from what
  it has gathered, so hitting `max_iterations` (default 9, per agent) usually
  still yields an answer.
- **Providers** (`agent/providers/`) and **tools** (`tools/runtime.nu`) are
  described below.

## Dependencies

### Nushell

The only mandatory dependency is [Nushell](https://nushell.sh). Everything else will just be tools and models configuration. You can also use Couchbase Shell as a replacement, which is also needed for some of the available tools. 

#### Nushell Plugin

##### nu_plugin_audio_hook

Install [nu_plugin_audio_hook](https://github.com/FMotalleb/nu_plugin_audio_hook) to get sounds notification at the end of an agent request.

### Models

### Providers

Each runtime is a module under `agent/providers/` exporting
`call [model messages model_tools options]`. They all take and return the same
OpenAI-shaped conversation (`{ choices: [{ message, finish_reason }], usage }`),
so the loop never knows which one answered; `agent/http.nu` supplies the shared
timeout, retry (with `retry-after`) and error reporting. Retry delays start at
`$env.AGENT_RETRY_BASE_DELAY` (default `2sec`) and double up to 60s.

#### OpenAi

OpenAI Agents will work as long as you have set your OpenAi API key.

`export OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxx`

To call any OpenAI-compatible server instead of api.openai.com (LiteLLM,
vLLM, ...), set `OPENAI_BASE_URL`. It follows the OpenAI SDKs' convention of
including the version segment, and the call goes to
`<base>/chat/completions`:

`export OPENAI_BASE_URL=http://localhost:4000/v1`

#### Anthropic

Set `"runtime": "anthropic"` in an agent's `agents.json` entry (e.g.
`"model": "claude-opus-4-5"`) and export your API key:

`export ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxx`

To call a server that speaks the Messages API instead of api.anthropic.com
(LiteLLM's `/v1/messages`, for example), set `ANTHROPIC_BASE_URL`. It follows
the Anthropic SDKs' convention of omitting the version segment, and the call
goes to `<base>/v1/messages` (a trailing `/v1` is tolerated):

`export ANTHROPIC_BASE_URL=http://localhost:4000`

Tool-calling (`model_tools`/`tool_functions`) works the same way it does
for the `openai` runtime -- `agent/providers/anthropic.nu` translates
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

This avoids IAM SigV4 request signing entirely -- `agent/providers/bedrock.nu`
is a plain HTTPS call to Bedrock's Converse API with an
`Authorization: Bearer` header, shaped like the other providers
rather than needing the AWS CLI or an AWS SDK. Converse is
provider-agnostic across every model Bedrock hosts, so tool-calling
(`model_tools`/`tool_functions`) works the same way it does for the other
runtimes -- `bedrock.nu` translates this repo's OpenAI-shaped
messages/tools/response convention to and from Converse's shape, so
`agent/agents.nu` and `agent/internal.nu` need no runtime-specific
handling.

#### Ollama

Follow their documentation on [https://github.com/ollama/ollama/blob/main/README.md#quickstart](https://github.com/ollama/ollama/blob/main/README.md#quickstart)

Make sure you have pulled models used by your agents first, and that your server is running on _localhost:11434_.

### Events, journals and observability

The loop reports everything it does as typed events (`agent/events.nu` has the
schema) and knows nothing about where they go. Choose sinks with
`$env.AGENT_SINKS` (or `--sinks` on `agent-ask`); the default is none, so a
plain run writes no files and sends nothing.

```sh
export AGENT_SINKS=jsonl,console,otel
```

| sink | what it does |
| --- | --- |
| `jsonl` | appends every event to a journal as it happens: `$AGENT_LOG_DIR` (default `logs/`) `/<time>-<run id>.jsonl`, readable only by you. The whole tree of sub-agent runs shares one file. |
| `console` | one-line progress on stderr: `▶ agent`, `→ tool`, `← tool ok`, `◀ done, 2 iteration(s), 30 tokens` |
| `otel` | exports spans, metrics and logs to an OTLP collector, in batches at the end of each iteration and of the run |

**The journal is what survives a crash.** Each event is written before anything
else happens to it, with start events as well as end events, so a journal that
ends in `tool.start` shows the process died inside that tool, and a gap in an
event's `seq` means lost lines. It is written whenever `jsonl` *or* `otel` is
selected. A journal can hold prompts and tool output: `AGENT_LOG_CONTENT=false`
keeps metadata only, and `AGENT_LOG_MAX_CONTENT` (default 20000) clips each
payload. Logging never stops a run: an unwritable directory or a down collector
warns once and the run carries on.

**Replaying a journal.** `agent-export [journal]` sends a journal (or every one
in the log directory) to the collector. Spans a killed process left open are
closed as failed (`run did not finish`), spans already sent are skipped (they
are listed in `<journal>.exported`), and a failed export can simply be retried.
With `AGENT_RECOVER=true`, `agent-ask` first replays any journal untouched for
`AGENT_RECOVER_MIN_AGE` (default `10min`).

On an ephemeral CI runner the disk goes with the job, so replay from a later
step of the same job (`if: always()`) to cover a crashed process; nothing but
data already sent survives the runner itself dying.

OTLP/HTTP+protobuf, configured with the standard environment:

```sh
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318   # default
export OTEL_EXPORTER_OTLP_HEADERS=x-api-key=abc,x-team=obs # optional, "k=v,k2=v2"
export OTEL_SERVICE_NAME=my-service                        # default nushell-agents
export OTEL_RESOURCE_ATTRIBUTES=deployment.environment=ci  # optional, "k=v,k2=v2"
export OTEL_SDK_DISABLED=true                              # turn all exporting off
export OTEL_CAPTURE_TOOL_CONTENT=true                      # also attach tool arguments/results to spans
```

Spans follow OpenTelemetry's GenAI conventions: `agent.run` > `agent.iteration`
> `gen_ai.chat` (with `gen_ai.client.token.usage` and
`gen_ai.client.operation.duration` histograms, and the raw reply as a log
record correlated to the span) and `execute_tool <name>`, plus counters
`agent.tool.call.count` and `agent.iteration.count`. A sub-agent's run nests
under the tool call that started it. Tool arguments and results are opt-in
because the spec flags them as possibly sensitive. Verified live against
[otel-desktop-viewer](https://github.com/CtrlSpice/otel-desktop-viewer) (a
local collector) and Arize Phoenix (an external one, protobuf-only).

`AGENT_COST_FILE` and `AGENT_LOG` are gone: per-call cost is on the `model.end`
events in the journal, and `console` replaces printing raw replies.

### Tools

#### Couchbase Shell

[Couchbase Shell](https://couchbase.sh) will be used to store data, expecially vectors, so that you can easily run Vector Search. Its configuration must allow you to create buckets, scopes, collections and indexes.

#### DDGR

The search tool relies on [DDGR](https://github.com/jarun/ddgr?tab=readme-ov-file#installation).

## Sessions

A conversation can outlive the process that started it:

```nushell
agent-ask "start a draft" -a writer --session draft1   # saves as it goes
agent-ask "now shorten it" --session draft1            # continues it (same agent)
agent-ask --resume draft1                              # picks up a run that was interrupted
agent-sessions                                         # what is saved
```

Sessions live in `$env.AGENT_SESSION_DIR` (default `sessions/`), one JSON file
each, mode `0600`, written atomically. A snapshot is the conversation itself
(not a log of it, so it works whether or not event content is captured). It is
saved when a run starts, after **every completed tool round**, and when the run
ends, so it never holds a tool call without its result. A run killed while a tool
or model call was in flight resumes from the last completed round: the model is
asked again and normally repeats the call. `--resume` takes no question for
that; give one to carry on with a follow-up instead.

Each snapshot has a revision number, and a save is refused if another process
changed the session in the meantime: the run stops with an error rather than
overwriting the other process's work. `run-agent --session <id>` is the same
thing from code; sub-agent runs are never sessions of their own.

## Budgets and context size

```json
"researcher": {
  "runtime": "openai", "model": "gpt-4o-mini",
  "max_total_tokens": 200000,
  "max_cost_usd": 0.50,
  "context": { "max_prompt_tokens": 60000, "keep_rounds": 2, "min_result_chars": 500 }
}
```

- **`max_total_tokens` / `max_cost_usd`** bound one run, sub-agents included. They
  are checked before each model call; once a run has used its allowance it stops
  with status `budget_exceeded` and returns whatever text the model had produced
  alongside its last tool calls. A sub-agent can use at most what is left of its
  caller's budget (and its own, if tighter). A single call that is already under
  way cannot be stopped, so a run can overshoot by up to one call. Cost needs a
  provider that reports it (a LiteLLM proxy does; api.anthropic.com does not):
  without it a warning is printed once and only the token budget is enforced.
- **`context`**: once the conversation grows past `max_prompt_tokens` (estimated
  at ~4 characters per token, or the last call's real prompt size if larger), the
  output of old tool calls is replaced by `[output elided to save context: N
  characters]`. The system prompt, user messages, the model's own messages and
  tool calls, the results of the last `keep_rounds` tool rounds, and outputs under
  `min_result_chars` are kept. It is deterministic and makes no model call, so it
  is free and cannot lose what the model itself wrote; it does lose the elided
  outputs themselves (the event journal still has them if content is captured).
  A `context.compacted` event records each time. Summarising with a model is not
  implemented.

## Sub-agents

An agent can use other agents as tools. List them in its manifest entry:

```json
"assistant": { "runtime": "openai", "model": "gpt-4o-mini",
               "agents": ["writer", "reviewer"], "description": "..." }
```

Each listed agent becomes a tool named after it, taking a `query`; its
description comes from that agent's own `description`. A call builds the agent
from the same manifest and runs it on a fresh conversation (it does not see the
caller's), and its answer is the tool result. A failing or incomplete sub-agent
is reported to the calling model as text, `tool_policy` can `ask` or `deny` a
sub-agent like any tool, and the run's `usage` and `subagents` include theirs.
Cycles (`a` -> `b` -> `a`), unknown names and broken sub-agent configs are
rejected when the agent is loaded; nesting deeper than `$env.AGENT_MAX_DEPTH`
(default 4) is refused at call time.

## Writing tools

A tool is a nu function that takes **one record** -- the model's parsed
arguments -- defined in the agent's `tool_functions` file and declared in its
`model_tools` JSON schema:

```nushell
def get_planet_mass [options] { match ($options.planet | str lowercase) { "mars" => 6.39e23, _ => 0.0 } }
```

The harness runs it with `tools/runtime.nu`'s `run-tool`: the arguments are
passed to the child process as data (never spliced into code), only tools the
agent declared can be called, each call has a timeout and an output cap, and a
failing tool is reported to the model as an `Error: ...` message so it can
recover. Per-agent settings in `agents.json`:

| key | meaning |
| --- | --- |
| `tool_policy` | `{ "default": "allow", "import_git_repo": "ask", "rm_rf": "deny" }` -- `ask` prompts at the terminal and refuses when there is none. The default falls back to `$env.AGENT_TOOL_POLICY`, then `allow`. |
| `tool_timeout` | seconds a single tool call may run (default 120). Needs `timeout` (or `gtimeout`) on the PATH. |
| `tool_shell` | `nu` (default) or `cbsh`, for tools that call Couchbase Shell (falls back to `$env.TOOL_SHELL`). |

`$env.AGENT_TOOL_MAX_OUTPUT` (default 50000) caps how many characters of a tool's
output reach the model.

## Tests

```sh
nu tests/run.nu                  # whole suite
nu tests/run.nu --filter retry   # tests whose name contains "retry"
```

Needs `nu` and `python3` (a scripted fake LLM server stands in for the
providers). The `mock` runtime replays a scripted conversation offline:
`{ "runtime": "mock", "responses": ["text", { "tool_calls": [{ "name": "t", "arguments": {} }] }] }`.

## Slides

Slides are displayed using [presenterm](https://github.com/mfontanini/presenterm).

```
cd slides
presenterm -x couchbase.md  # -x flag enables code execution from the slides, hit ctrl-e to run code during the presentation. 
```

### Enabling slide nushell hightlighting

Installing presenterm from source is mandatory for this.

Nushell code highlighting is not available by default. To build it, place [the synthax file](https://github.com/kurokirasama/nushell_sublime_syntax/blob/main/nushell.sublime-syntax) in your bat config folder and rebuild it. Then copy and paste the synthax file in your local presenterm installation and rebuild it.
