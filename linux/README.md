## Solana Customized Rust for Linux that supports Berkley Packet Filter (BPF)

This Docker contains Rust binaries that incorporate customizations and fixes required
by Solana but not yet upstreamed into Rust or LLVM

https://hub.docker.com/r/solanalabs/rust/

### Usage:

This Docker is optionally used by the Solana SDK BPF build system.

### Notes:

Attempting to build Rust im travis-ci takes too long and times out, leaving .travis.yml file here for reference and possibly using CI in the future.
