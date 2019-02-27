#!/usr/bin/env bash
set -ex

cd "$(dirname "$0")"

docker build --no-cache -t solanalabs/rust-bpf .

rm -rf out
mkdir -p out
cd out

# Copy out and bundle release products
mkdir -p deploy
id=$(docker create solanalabs/rust-bpf)
docker cp "$id":/usr/local/version.md deploy
docker cp "$id":/usr/local/bin deploy
docker cp "$id":/usr/local/lib deploy
docker rm -v "$id"
mkdir deploy/lib/rustlib/x86_64-unknown-linux-gnu/bin
tar -C deploy -jcf solana-rust-bpf-linux.tar.bz2 .

# docker push solanalabs/rust-bpf
