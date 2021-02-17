#!/usr/bin/env bash
set -ex

cd "$(dirname "$0")"

docker build --no-cache  -t solanalabs/bpf-tools .
id=$(docker create solanalabs/bpf-tools)

rm -rf out
mkdir -p out
cd out

# Copy rust build products
mkdir -p deploy/rust
docker cp "$id":/usr/local/rust/rust_version.md deploy/rust
docker cp "$id":/usr/local/rust/cargo_version.md deploy/rust
docker cp "$id":/usr/local/rust/bin deploy/rust
docker cp "$id":/usr/local/rust/lib deploy/rust
mkdir -p deploy/rust/lib/rustlib/x86_64-unknown-linux-gnu/bin # Needed by xargo

# Copy llvm build products
mkdir -p deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/clang deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/clang++ deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/clang-10 deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/clang-cl deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/clang-cpp deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/ld.lld deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/ld64.lld deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/llc deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/lld deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/lld-link deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/llvm-ar deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/llvm-objcopy deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/llvm-objdump deploy/llvm/bin
docker cp "$id":/usr/local/llvm/bin/llvm-readelf deploy/llvm/bin
mkdir -p deploy/llvm/lib
docker cp "$id":/usr/local/llvm/lib/ deploy/llvm/lib

docker rm -v "$id"

