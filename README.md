# Customized Rust/Clang toolchain for Solana Platform

[![Build Status](https://github.com/anza-xyz/platform-tools/actions/workflows/main.yml/badge.svg)](https://github.com/anza-xyz/platform-tools/actions/)

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

* https://github.com/anza-xyz/rust
* https://github.com/anza-xyz/llvm-project
* https://github.com/anza-xyz/compiler-builtins
* https://github.com/anza-xyz/newlib
* https://github.com/anza-xyz/cargo

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

### Version Compatibility

Each platform-tools release pins a `solana-tools-v*` tag in [anza-xyz/rust].
That tag fixes both the Rust version and the LLVM branch the release is built
from.

You can see these versions in the release notes.

### Target Architectures

Each release ships one rustlib per target triple.  Which triples are shipped
has changed over time.

The current target is `sbpfv3-solana-solana` (SBPFv3).

> **Do not build SBPFv3 programs with v1.44 – v1.51.**
>
> Those releases ship an `sbpfv3-solana-solana` rustlib, but a different LLVM
> definition, which is *not* the SBPFv3 supported by the Solana network.

v1.52 shipped no `sbpfv3-solana-solana` rustlib at all.

From v1.53, `Proc<"v3">` is `[StaticSyscalls, RelocAbs64, Jmp32, CallxRegDst,
NoStackGaps, StackGrowsUp]`. The linker script matches the current memory
layout, and the object writer emits `EM_BPF`.

Use v1.53 or later to build SBPFv3 programs.

[anza-xyz/rust]: https://github.com/anza-xyz/rust
[SIMD-0178]: https://github.com/solana-foundation/solana-improvement-documents/blob/main/proposals/0178-static-syscalls.md
[SIMD-0189]: https://github.com/solana-foundation/solana-improvement-documents/blob/main/proposals/0189-sbpf-stricter-elf-headers.md
[SIMD-0377]: https://github.com/solana-foundation/solana-improvement-documents/blob/main/proposals/0377-ebpf-isa-compatibility.md
