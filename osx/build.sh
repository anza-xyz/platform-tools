#!/usr/bin/env bash
set -ex

cd "$(dirname "$0")"

rm -rf out
mkdir -p out
cd out

git clone https://github.com/solana-labs/rust.git
echo "$( cd rust && git rev-parse HEAD )  https://github.com/solana-labs/rust.git" >> version.md

pushd rust
./build.sh
popd

# Copy build products
mkdir -p deploy
cp version.md deploy
cp -rf rust/build/x86_64-apple-darwin/stage1/ deploy

# Needed by xargo
mkdir deploy/lib/rustlib/x86_64-apple-darwin/bin

tar -C deploy -jcf solana-rust-bpf-osx.tar.bz2 .