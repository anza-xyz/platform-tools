# Customized Ruyst binaries for Solana that support Berkley Packer Filter (BPF)

Builds Rust binaries that incorporate customizations and fixes required
by Solana but not yet upstreamed into Rust or LLVM.

* Builds Rust for Linux (Debian)
* Builds Rust for MacOS natively therefore skipped if not building on a Mac
* Results in tarballs in `/deploy` that can be released

### Building

```bash
$ ./build.sh
```

* Builds Rust for Linux in Docker, tags and pushes `solanalabs/rust`
* Copies Rust for Linux out of Docker the zips the products into `/deploy`
* Builds Rust for MacOS natively and zips the products into `/deploy`

### Releases

This repo depends on the following:

* https://github.com/solana-labs/rust

Any changes that need to go into a Rust release must be made in the appropriate repos listed above.

* See `linux/Dockerfile` for an example of how to sync and build for Linux
* See `macos/build.sh` for an example of how to sync and build for MacOS)