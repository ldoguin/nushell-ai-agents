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

#### Ollama

Follow their documentation on [https://github.com/ollama/ollama/blob/main/README.md#quickstart](https://github.com/ollama/ollama/blob/main/README.md#quickstart)

Make sure you have pulled models used by your agents first, and that your server is running on _localhost:11434_.

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
