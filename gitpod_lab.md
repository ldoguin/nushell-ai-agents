# Gitpod Lab

There are a couple things you need to do in order to run this example.

## Add your API Kkey as environment variable

```bash
export OPEN_API_KEY="sk-proj-yourAPIKey"
```
## Edit Couchbase Shell Configuration

Open the config file and add your llm configuration:

```bash
open /home/gitpod/.cbsh/config
```

and copy paste 

```
[[llm]]
identifier = "OpenAI"
provider = "OpenAI"
embed_model = "text-embedding-3-small"
chat_model = "gpt-3.5-turbo"
api_key = "sk-proj-yourAPIKey"
```

## Setup Couchbase VSCode extension

Click on the Couchbase logo, then on the plus sign at the top right, you should only have to fill the Name field and click Connect.

## Run the example

```bash
nu
source agent.nu
run "who are the contibutors of the github project couchbaselabs/couchbase-shell"
```