# Customized Rust/Clang toolchain for Solana Platform

[![Build Status](https://github.com/solana-labs/platform-tools/actions/workflows/main.yml/badge.svg)](https://github.com/solana-labs/platform-tools/actions/)

Builds Clang and Rust compiler binaries that incorporate
customizations and fixes required by Solana but not yet upstreamed
into Rust or LLVM.

* Builds Rust for Linux (Debian) natively, or in Docker if runs on MacOS
* Builds Rust for MacOS natively therefore skipped if not building on a Mac
* Results in tarballs in `out/` that can be released

### Building

```bash
$ ./build.sh [--docker]
```

The `--docker` option can be used to build Linux binaries on macOS in
a docker container.  If the option is not specified only macOS
binaries are built on a Mac.  On Linux the `--docker` option is
ignored.

### Releases

This repo depends on the following:

* https://github.com/solana-labs/rust
* https://github.com/solana-labs/llvm-project
* https://github.com/solana-labs/compiler-builtins
* https://github.com/solana-labs/newlib
* https://github.com/solana-labs/cargo

Any changes that need to go into a Rust release must be made in the
appropriate repos listed above.

* See `build.sh` for an example of how to sync and build

This repository is used to build the toolchain binaries in GitHub
Actions.  The created tarballs are uploaded as build artifacts in
GitHub Actions.

The release of the binaries is fully automated.  Do not release
manually.  To release the binaries, push a release tag that starts
with the '*v*' character, e.g. `v1.2`.  The GitHub workflow
automatically triggers a new build, creates a release with the name of
the tag, and uploads the toolchain tarballs as the release assets.
