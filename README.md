# Solana  Berkley Packer Filter (BPF) tools bundle

[![Build Status](https://travis-ci.org/solana-labs/rust-bpf-builder.svg?branch=master)](https://travis-ci.org/solana-labs/bpf-tools)

Builds Rust and llvm binaries that incorporate customizations and fixes required
by Solana but not yet upstreamed into Rust or LLVM.

### Building

```bash
$ ./build.sh
```

* Builds Rust for Linux in Docker, tags and pushes `solanalabs/rust`
* Copies Rust for Linux out of Docker the zips the products into `/deploy`
* Builds Rust for MacOS natively and zips the products into `/deploy`
* Results in tarballs in `/deploy` that can be released

### Releases

This repo depends on the following:

* https://github.com/solana-labs/rust

* See `linux/Dockerfile` for an example of how to sync and build for Linux
* See `macos/build.sh` for an example of how to sync and build for MacOS)
