FROM laurentdoguin/workspace-couchbase-base

# Install dependencies
RUN sudo apt update && sudo apt install ddgr && cargo install nu && cargo install --git https://github.com/couchbaselabs/couchbase-shell
