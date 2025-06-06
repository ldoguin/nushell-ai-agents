# Gitpod Lab

There are a couple things you need to do in order to run this example.

## Install Couchbase Shell

```
wget https://github.com/couchbaselabs/couchbase-shell/releases/download/v1.1.0/cbsh-x86_64-unknown-linux-gnu.tar.gz
tar -zxvf cbsh-x86_64-unknown-linux-gnu.tar.gz cbsh
sudo cp cbsh /usr/bin/cbsh
rm ./cbsh cbsh-x86_64-unknown-linux-gnu.tar.gz
```
Run `cbsh`, you will be prompted with the creation of a default config file. More information can be found on [couchbase.sh](http://couchbase.sh/docs/).


## Add your API key as environment variable

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

## Install and configure Couchbase Edge Server

Download the .deb installer on https://www.couchbase.com/downloads/?family=edge-server

Run `sudo dpkg -i ./couchbase-edge-server_1.0.0_amd64.deb`

Add it to the current Path by running `export PATH=$PATH:/opt/couchbase-edge-server/bin/`

Than add those environment variables
```
export CBES_BASE_URL="https://localhost:60000"
export CBES_PASSWORD=administrator
export CBES_USERNAME=administrator
export CBES_CACERT_PATH=./couchbase-edge-server/certificate.pem
```

You can start by generating a certificate like this:
```
 default 🏠 default in 🗄 default._default._default
> run "create a certificate and key pair for CN=localhost in the directory couchbase-edge-server "
create a certificate and key pair for CN=localhost in the directory couchbase-edge-server 
Created anonymous certificate with CN='localhost' in file couchbase-edge-server/certificate.pem with private key couchbase-edge-server/private.key
```

You can edit `couchbase-edge-server/cbes_config.json` accordingly. Now you can open another terminal tab and run:

```
export PATH=$PATH:/opt/couchbase-edge-server/bin/
cd couchase-edge-server
couchase-edge-server cbes_config.json
```

This will start Edge Server. You can now go back to the other tab and start playing with agents.

```
👤 default 🏠 default in 🗄 default._default._default
> run "list the databases, then their info and keyspaces" | run "query all document for all keyspaces"
list the databases, then their info and keyspaces
query all document for all keyspaces {"db_name":"american234","db_uuid":"d8090291e33543af9bde2146f9f5ef87","collections":{"AmericanAirlines.AA234":{"doc_count":0,"update_seq":0}}}

{"db_name":"american234","db_uuid":"d8090291e33543af9bde2146f9f5ef87","collections":{"AmericanAirlines.AA234":{"doc_count":0,"update_seq":0}}}

👤 Administrator 🏠 default
> ls . | get 0 | to json -r | run "create a new document in keyspace american234.AmericanAirlines.AA234 with the following content "
create a new document in keyspace american234.AmericanAirlines.AA234 with the following content  {"name":"Dockerfile","type":"file","size":205,"modified":"2025-06-03 16:15:32.038444781 +00:00"}
{"keyspace":"american234.AmericanAirlines.AA234","document":"{\"name\":\"Dockerfile\",\"type\":\"file\",\"size\":205,\"modified\":\"2025-06-03 16:15:32.038444781 +00:00\"}"}
{"ok":true,"id":"~lWpPj1CLWwwjoiWMzplVk9","rev":"1-151ab05f7cc5adf561f073cb57d1a79d11b64408"}

```