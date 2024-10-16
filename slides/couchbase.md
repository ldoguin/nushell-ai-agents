---
theme:
  override:
    code:
      alignment: left
      background: false
      
title: Ai Agents in the Terminal
sub_title: (Because Python 🙈 ? )
author: Laurent Doguin
---

Agenda
===
<!-- jump_to_middle -->

<!-- incremental_lists: true -->

# Couchbase Shell
# LLM Overview
# Agents

<!-- end_slide -->
<!-- jump_to_middle -->
Couchbase Shell
===
<!-- end_slide -->


Nushell
===

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

# In a Nuthsell:

* available on nushell.sh
* multiplatform
* use schemaless dataframes in and out
* plugin support
* basic unix commands

<!-- column: 1 -->

```nushell +exec

ls
```

```nushell +exec

ls
ls | where size > 4KiB | sort-by modified
```
<!-- end_slide -->

Couchbase Shell
===

# A Nushell wrapper dedicated to Couchbase

* Manage Clusters OnPrem or Capella
* Available in your IDE plugins, from your favorite* package manager
* Releases on github.com/couchbaselabs/couchbase-shell
* More on https://couchbase.sh/docs/recipes
* and https://couchbase.sh/docs/

\* if your favorite package manager is Cargo, contributions welcomed

```bash
👤 Charlie 🏠 obligingfaronmoller in ☁️ default._default._default
> cb-env managed
╭───┬────────┬───────┬────────────┬───────────────┬──────────────────────┬─────────────────╮
│ # │ active │  tls  │ identifier │   username    │ capella_organization │     project     │
├───┼────────┼───────┼────────────┼───────────────┼──────────────────────┼─────────────────┤
│ 0 │ false  │ true  │ systemtest │ Administrator │ my-org       │ CBShell Testing │
│ 1 │ false  │ false │ localdev   │ Administrator │      │ │
│ 2 │ false  │ true  │ prod       │ Administrator │ my-org       │ CBShell Testing │
│ 3 │ true   │ true  │ ci │ Administrator │ my-org       │ CBShell Testing │
╰───┴────────┴───────┴────────────┴───────────────┴──────────────────────┴─────────────────╯

```
<!-- end_slide -->

List your cluster nodes
===

```bash
👤 Charlie 🏠 localdev in 🗄 travel-sample._default._default
> nodes --clusters *
╭────┬─────────────────────────┬─────────────────────────────────────────────────────────────┬─────────┬──────────────────────────┬───────────────────────┬───────────────────────────┬──────────────┬─────────────┬─────╮
│  # │ cluster │       hostname      │ status  │ services │version│    os     │ memory_total │ memory_free │ ... │
├────┼─────────────────────────┼─────────────────────────────────────────────────────────────┼─────────┼──────────────────────────┼───────────────────────┼───────────────────────────┼──────────────┼─────────────┼─────┤
│  0 │ localdev│ 192.168.107.128:8091│ healthy │ search,indexing,kv,query │ 7.6.2-3505-enterprise │ aarch64-unknown-linux-gnu │   6201221120 │  2841657344 │ ... │
│  1 │ localdev│ 192.168.107.129:8091│ healthy │ search,indexing,kv,query │ 7.6.2-3505-enterprise │ aarch64-unknown-linux-gnu │   6201221120 │  2842959872 │ ... │
│  2 │ localdev│ 192.168.107.130:8091│ healthy │ search,indexing,kv,query │ 7.6.2-3505-enterprise │ aarch64-unknown-linux-gnu │   6201221120 │  2843160576 │ ... │
│  3 │ prod    │ svc-dqi-node-001.lhb4l06lajhydwmk.cloud.couchbase.com:8091  │ healthy │ indexing,kv,query│ 7.6.2-3721-enterprise │ x86_64-pc-linux-gnu       │  16776548352 │ 15518982144 │ ... │
│  4 │ prod    │ svc-dqi-node-002.lhb4l06lajhydwmk.cloud.couchbase.com:8091  │ healthy │ indexing,kv,query│ 7.6.2-3721-enterprise │ x86_64-pc-linux-gnu       │  16776548352 │ 15518420992 │ ... │
│  5 │ prod    │ svc-dqi-node-003.lhb4l06lajhydwmk.cloud.couchbase.com:8091  │ healthy │ indexing,kv,query│ 7.6.2-3721-enterprise │ x86_64-pc-linux-gnu       │  16776544256 │ 15501099008 │ ... │
│  6 │ ci      │ svc-dqi-node-001.fwplhqyopu9pgolq.cloud.couchbase.com:8091  │ healthy │ indexing,kv,query│ 7.6.2-3721-enterprise │ x86_64-pc-linux-gnu       │  16277504000 │ 14538944512 │ ... │
│  7 │ ci      │ svc-dqi-node-002.fwplhqyopu9pgolq.cloud.couchbase.com:8091  │ healthy │ indexing,kv,query│ 7.6.2-3721-enterprise │ x86_64-pc-linux-gnu       │  16277504000 │ 14559510528 │ ... │
│  8 │ ci      │ svc-dqi-node-003.fwplhqyopu9pgolq.cloud.couchbase.com:8091  │ healthy │ indexing,kv,query│ 7.6.2-3721-enterprise │ x86_64-pc-linux-gnu       │  16277504000 │ 14565412864 │ ... │
│  9 │ systemtest      │ svc-dqi-node-001.lyl8kbhzdovyqhv.cloud.couchbase.com:8091   │ healthy │ indexing,kv,query│ 7.6.2-3721-enterprise │ x86_64-pc-linux-gnu       │  16766582784 │ 15491842048 │ ... │
╰────┴─────────────────────────┴─────────────────────────────────────────────────────────────┴─────────┴──────────────────────────┴───────────────────────┴───────────────────────────┴──────────────┴─────────────┴─────╯
```

<!-- end_slide -->

Common Operations
===


```bash 
# Insert a document
👤 Charlie 🏠 local in 🗄 default._default._default
> open mydoc.json | wrap content | insert id $in.content.id | doc upsert
╭───┬───────────┬─────────┬────────┬──────────┬─────────╮
│ # │ processed │ success │ failed │ failures │ cluster │
├───┼───────────┼─────────┼────────┼──────────┼─────────┤
│ 0 │ 1 │       1 │      0 │  │ local   │
╰───┴───────────┴─────────┴────────┴──────────┴─────────╯

# Migrate query index definitions
👤 Charlie 🏠 local in 🗄 default._default._default
> query indexes --definitions --clusters "On-Prem-Cluster" | get definition | each { |it| query $it --clusters "Capella-Cluster" }

# Migrate all collections, except the _default collection:
👤 Charlie 🏠 local in 🗄 default._default._default
> (
  collections --clusters "On-Prem-Cluster" --bucket "travel-sample" | 
  select scope collection | where $it.scope != "_default" | where $it.collection != "_default" |
  each { |it| collections create $it.collection --clusters "Capella-Cluster" --bucket "travel-sample-import" --scope $it.scope }
) 

```

<!-- end_slide -->

Scripting
===

```nushell +exec
# Create given bucket, scope, collection and primary index if they don't exist
def dbSetup [bucket: string; scope: string; collection: string] {
    cb-env | print
    if (buckets| where name == $bucket | is-empty) {buckets create --replicas 1 $bucket 100; print $"Create Bucket ($bucket)"} else {print "Bucket already exist"}
    cb-env bucket $bucket
    if (scopes| where scope == $scope | is-empty) {scopes create $scope; print $"Create Scope ($scope)"} else {print "Scope already exist"}
    cb-env scope $scope
    if (collections| where collection == $collection | is-empty) {collections create $collection; print $"Create Collection ($collection)"} else {print "Collection already exist"}
    cb-env collection $collection
    query $"CREATE PRIMARY INDEX IF NOT EXISTS ON `default`:`($bucket)`.`($scope)`.`($collection)`"
    cb-env
}
```


<!-- end_slide -->

Github Action support
===
Available on https://github.com/ldoguin/setup-cbsh/
```yaml
name: Test Couchbase connection
on: [workflow_dispatch]
defaults:
  run:
    shell: cbsh --script {0}

env:
  COUCHBASE_DEFAULT_BUCKET:  spring_${{ vars.COUCHBASE_DEFAULT_BUCKET }}
  COUCHBASE_DEFAULT_SCOPE:  ${{ github.head_ref || github.ref_name }}_${{ vars.COUCHBASE_DEFAULT_SCOPE }}
  COUCHBASE_DEFAULT_COLLECTION:  ${{ vars.COUCHBASE_DEFAULT_COLLECTION  }}
  ....

jobs:
  setup:
    runs-on: ubuntu-22.04
    steps:
    - name: Checkout ${{ github.event.repository.name }}
      uses: actions/checkout@v4
    #Install Couchbase Shell
    - uses: ldoguin/setup-cbsh@main
      with:
version: '1.0.0'
enable-plugins: ''
config:  ${{ secrets.CBSHELL_CONFIG }}
    # Run cbsh scripts
    - name: Setup Couchbase Bucket, Scope, Collection
      run: |
  source ${{ github.workspace }}/scripts/dbSetup.nu
  dbSetup $env.COUCHBASE_DEFAULT_BUCKET $env.COUCHBASE_DEFAULT_SCOPE $env.COUCHBASE_DEFAULT_COLLECTION
    # Run your test than tear down
    - name: Tear Down Bucket
      run: |
cb-env bucket $env.COUCHBASE_DEFAULT_BUCKET
scopes drop $env.COUCHBASE_DEFAULT_SCOPE

```
<!-- end_slide -->

<!-- jump_to_middle -->
Large Language Models
===
<!-- end_slide -->


A Quick LLM Overview
===

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

 <!-- new_lines: 5 -->
* Autocomplete but better
* An LLM understands emebddings
* Need to convert data to embedding

<!-- column: 1 -->

```nushell +exec
(
  curl -s "https://api.openai.com/v1/embeddings" 
  -H $"Authorization: Bearer ($env.OPENAI_API_KEY)" 
  -H "Content-Type: application/json" 
  -d '{
    "input": "The food was delicious and the waiter...",
    "model": "text-embedding-ada-002",
    "encoding_format": "float"
  }'
) | from json 
```
<!-- end_slide -->


LLM Usage History
===

# A story of AutoComplete and Anthropomorphism

* From Completion
  * A System Role
  * An Assitant Role
  * A User Role
* To Chatbot
  * Maintain a conversation and its history
  * A Tool role

```nushell +exec
(curl -s "https://api.openai.com/v1/chat/completions"
  -H "Content-Type: application/json" 
  -H $"Authorization: Bearer ($env.OPENAI_API_KEY)" 
  -d '{
    "model": "gpt-4o",
    "messages": [
      {
"role": "system",
"content": "You are a helpful assistant."
      },
      {
"role": "user",
"content": "Hello! How can I get out of jail ?"
      }
    ]
  }'
) | save -f history.txt

```
<!-- end_slide -->

LLM Answer
===

# Is this the answer I wanted ?

```nushell +exec
open history.txt

```
<!-- end_slide -->
LLM Answer
===

# Using Nushell to filter data

```nushell +exec
open history.txt | from json | $in.choices.0.messages

```
<!-- end_slide -->
LLM Answer
===

# Using Nushell to filter data

```nushell +exec
open history.txt | from json | $in.choices.0.message

```
<!-- end_slide -->

Using RAG to fight hallucination
===

# Retrieval Augmented Generation

* Turning Data in vectors
* Storing and querying vectors

```nushell 
# Turn the PDF file in chunked text
> pdftotext monopolyInstruction.pdf
# Insert it to Couchbase
> open monopolyInstruction.txt |split row "
::: 
::: "|wrap text | wrap content | each { insert id { random uuid } } | doc upsert
# Create an Embedding
> query "SELECT meta().id as id, p.* from pdf as p" | wrap content| vector enrich-doc text | doc upsert
# Create an Index
> vector create-index pdf textVector 1536
# Ask the question with Couchbase Shell
> ( 
    let question = "how to get out of jail"; vector enrich-text $question |
    vector search pdf textVector | select id |doc get| select content.text |
    ask $question 
  )

$questionEmbedding batch 1/1
You can get out of jail by following these methods:
1. **Roll Doubles:** If you roll a double with the white dice on any of your next three turns, you can immediately move out of Jail. You then move the number of spaces shown by your doubles roll.
2. **"Get Out of Jail Free" Card:** If you have a "Get Out of Jail Free" card, you can use it to get out of Jail without rolling doubles. This card can be obtained by purchasing it from another player or drawing it from the Chance or Community Chest cards.
3. **Pay Fine:** You can also choose to pay a fine of $50 before you roll the dice on either of your next two turns. After paying the fine, you are free to move and continue playing.
Remember, if you do not roll doubles by your third turn or use a "Get Out of Jail Free" card, you must pay the $50 fine to get out of Jail.
```


<!-- end_slide -->

<!-- jump_to_middle -->
Ai Agents
===
<!-- end_slide -->


Agents ?
===


<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

## Handing out reasoning and execution

* We decided of the query, we reasoned about the problem
* And Acted upon it

* The ReAct/TAO pattern
* Though Action Observation


### A custom system prompt for agent: 
```
You run in a loop of Thought, Action, PAUSE, Observation.
At the end of the loop you output an Answer
Use Thought to describe your thoughts about the question you have been asked.
Use Action to run one of the actions available to you - then return [{"step":"PAUSE"}].
Observation will be the result of running those actions.

Your available actions are:

calculate:
e.g. {"calculate": "4 * 7 / 3"}
Runs a calculation and returns the number - uses Python so be sure to use floating point syntax if necessary

get_planet_mass:
e.g. {"get_planet_mass": "Earth"}
returns weight of the planet in kg

Example session:

[
    {"step":"Question", "msg": "What is the mass of Earth times 2?"},
    {"step":"Thought", "msg": "I need to find the mass of Earth"},
    {"step":"Action, "msg": {"get_planet_mass": "Earth"}},
    {"step":"PAUSE"}
]
You will be called again with this:
```
<!-- column: 1 -->

```
{"step":"Observation", "msg": "5.972e24"}

You can then anwser with the follow up tought:

[
    {"step":"Thought", "msg": "I need to multiply this by 2"},
    {"step":"Action, "msg": {"calculate": "5.972e24 * 2"}},
    {"step":"PAUSE"}
]

You will be called again with this: 

{"step":"Observation", "msg": "1,1944×10e25"}

If you have the answer, output it as the Answer.

[{"step" : "Answer", "msg" : "The mass of Earth times 2 is 1,1944×10e25."}]

Always return a valid JSON array structure with each steps as element of the array.

Now it is your turn:
```

<!-- end_slide -->

Introducing Tool Support
===

 * We need better tooling than parsing string, even structured string like JSON
 * Introducing Tools, a built-in TAO/ReAct pattern
 * The list of available functions is given to the chat model call directly.

Let's see how it works for real

<!-- end_slide -->

