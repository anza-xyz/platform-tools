#!/usr/bin/env bash
set -ex

cd "$(dirname "$0")"

rm -rf out
mkdir -p out
cd out

git clone --single-branch --branch solana-1.39 https://github.com/solana-labs/rust.git
echo "$( cd rust && git rev-parse HEAD )  https://github.com/solana-labs/rust.git" >> version.md

git clone --single-branch --branch rust-1.39.0 https://github.com/rust-lang/cargo.git
echo "$( cd cargo && git rev-parse HEAD )  https://github.com/rust-lang/cargo.git" >> version.md

pushd rust
./build.sh
popd

pushd cargo
export OPENSSL_STATIC=1
cargo build --release
popd

# Copy build products
mkdir -p deploy/bin
cp version.md deploy
cp -rf rust/build/x86_64-apple-darwin/stage1/ deploy
cp cargo/target/release/cargo deploy/bin/

# Needed by xargo
mkdir -p deploy/lib/rustlib/x86_64-apple-darwin/bin

tar -C deploy -jcf solana-rust-bpf-osx.tar.bz2 .
