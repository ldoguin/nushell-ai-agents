# Self-improving agents

An agent in this repository is a set of files that are read again on every
run: a prompt, a `tools.json`, a `functions.nu` and optionally a memory
file. This folder lets one agent edit those files for another agent, or
for itself, and keeps a change only when it measurably helps.

```
nu improve/improve.nu eval <agent>       # score an agent on evals/<agent>.json
nu improve/improve.nu run <agent> -n 3   # make 3 improvement attempts
nu improve/improve.nu history <agent>    # list the attempts made so far
nu improve/test.nu                       # end-to-end test, no API key needed
```

Run everything from the repository root, on a branch, with a clean working
tree. The default improver is the `self_improver` agent in `agents.json`,
which needs `ANTHROPIC_API_KEY`; pass `--improver <agent>` to use another.

## What one attempt does

1. **Evaluate.** The target agent runs on every task in
   `evals/<agent>.json`. That gives a baseline score.
2. **Brief.** The improver is given the target's configuration and file
   list, the train tasks it fails with what it did and answered, and a
   summary of earlier attempts.
3. **Edit.** The improver reads and edits files with the tools in
   `tools_catalog/self/`.
4. **Check.** The attempt is rejected straight away if the improver
   failed, changed nothing, changed a file outside the writable scope, or
   left a `.nu` or `.json` file that does not parse.
5. **Re-evaluate and decide.** The target runs on all tasks again. The
   change is kept if the score did not drop on either split and either
   score rose, or utility rose by at least `--min-gain` (default 0.01).
6. **Record.** A kept change is committed. A rejected one is reverted.
   Either way the attempt, its scores and its patch are committed under
   `improve/archive/`, so the next attempt can see what was tried.

## Writing a task file

`evals/<agent>.json`:

```json
{
  "token_cap": 20000,
  "time_cap_sec": 120,
  "tasks": [
    { "id": "mars", "query": "What is the mass of Mars?", "expect": { "contains": ["6.39"] } },
    { "id": "moon", "query": "What is the mass of the Moon?", "expect": { "regex": "7\\.3\\d" }, "split": "holdout" }
  ]
}
```

- `expect` can combine `contains` and `not_contains` (lists,
  case-insensitive), `regex` and `equals`. A task passes when all hold.
- Tasks are `train` unless marked `"split": "holdout"`. The improver only
  sees failing train tasks. Holdout tasks check that a change generalizes,
  so keep some.
- **Score** is the share of tasks passed. **Utility** is
  `0.5 * score + 0.25 * (1 - tokens/token_cap) + 0.25 * (1 - seconds/time_cap_sec)`,
  averaged per task, so cheaper and faster agents win ties.
  `time_cap_sec` is also the per-task timeout.

Model answers vary from run to run and each task runs once, so a small
task file gives a noisy score. Use enough tasks that one flipped answer
does not decide the outcome.

## What the improver can touch

`improve/scope.json` decides:

| Key | Meaning | Default |
|---|---|---|
| `writable` | Path prefixes it may create or change | `prompts`, `tools_catalog`, `memory` |
| `protected` | Read-only exceptions inside `writable` | `tools_catalog/self/functions.nu` |
| `unreadable` | Path prefixes it may not read | `evals`, `logs`, `improve/archive` |

Everything else is read-only. The scope is enforced twice: by the file
tools, and again by the loop, which looks at what actually changed on disk
with `git status`. The harness core (`agent/`), the loop (`improve/`) and
the task files (`evals/`) are outside the scope, so the improver cannot
rewrite the rules it is judged by. To let it change more, for example
`agents.json` or `agent/`, add the path to `writable`. A broken change to
the harness core is caught by the re-evaluation and reverted like any
other.

To make an agent improve itself, pass its own name as the target:
`nu improve/improve.nu run self_improver`. It needs a task file like any
other agent.

## Harness features this relies on

All three are optional keys of an `agents.json` entry and can be used on
their own:

- `"tool_call_mode": "json"` passes the model's tool arguments to the tool
  function as one record, through a temporary file. The default mode
  pastes them into a shell command and treats `name(...)` inside them as a
  nested tool call, which corrupts source code passed as an argument.
- `"max_iterations": 40` sets how many model calls one run may make
  (default 9).
- `"memory": "memory/<agent>.md"` appends that file to the system prompt.
  The `remember` tool adds one-line lessons to it.

There is also a `"runtime": "mock"` that replays a scripted conversation
from a JSON file (`options.script`), used by `improve/test.nu`.

## Where the design comes from

- [Darwin Gödel Machine](https://arxiv.org/abs/2505.22954): accept
  self-modifications on benchmark evidence instead of proofs, keep an
  archive of every attempt, restrict what can be modified, keep changes
  traceable.
- [SICA](https://arxiv.org/abs/2504.15228): one utility number that
  combines benchmark score, cost and time.
- [Hermes Agent](https://github.com/NousResearch/hermes-agent) and
  [GEPA](https://arxiv.org/abs/2507.19457): memory as markdown loaded into
  the system prompt, improvement driven by reading execution traces, and
  an evaluator that is separate from the agent being improved.

Two things those systems do that this loop does not: it always builds on
the last accepted version instead of sampling parents from the archive,
and it has no LLM judge, so tasks need answers that string checks can
grade.
