#!/usr/bin/env bash
set -ex

cd "$(dirname "$0")"

rm -rf out
mkdir -p out
cd out

git clone --single-branch --branch solana-1.46 https://github.com/solana-labs/rust.git
echo "$( cd rust && git rev-parse HEAD )  https://github.com/solana-labs/rust.git" >> version.md

# note, branch v1.46.0, v1.47.0, and v1.48.0 fail to build
git clone --single-branch --branch rust-1.49.0 https://github.com/rust-lang/cargo.git
echo "$( cd cargo && git rev-parse HEAD )  https://github.com/rust-lang/cargo.git" >> version.md

pushd rust
./build.sh --llvm
popd

pushd cargo
export OPENSSL_STATIC=1
cargo build --release
popd

# Copy rust build products
mkdir -p deploy/rust/bin
cp version.md deploy
cp -rf rust/build/x86_64-apple-darwin/stage1/* deploy/rust
cp cargo/target/release/cargo deploy/rust/bin/
mkdir -p deploy/rust/lib/rustlib/x86_64-apple-darwin/bin # Needed by xargo

# Copy llvm build products
mkdir -p deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/clang deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/clang++ deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/clang-10 deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/clang-cl deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/clang-cpp deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/ld.lld deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/ld64.lld deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/llc deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/lld deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/lld-link deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/llvm-ar deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/llvm-objcopy deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/llvm-objdump deploy/llvm/bin
cp -rf rust/build/x86_64-apple-darwin/llvm/build/bin/llvm-readelf deploy/llvm/bin
mkdir -p deploy/llvm/lib
cp -rf rust/build/x86_64-apple-darwin/llvm/build/lib/ deploy/llvm/lib

tar -C deploy -jcf solana-bpf-tools-osx.tar.bz2 .
