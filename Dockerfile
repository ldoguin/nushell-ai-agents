FROM laurentdoguin/workspace-couchbase-base

# Install dependencies
RUN sudo apt update && sudo apt install ddgr && cargo install nu && cargo install --git https://github.com/couchbaselabs/couchbase-shell

RUN cargo install nu_plugin_audio_hook --features=all-decoders  && cbsh -c 'plugin add ~/.cargo/bin/nu_plugin_audio_hook'
