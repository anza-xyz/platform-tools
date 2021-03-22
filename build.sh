#!/usr/bin/env bash
set -ex

if [ "$(uname)" == "Darwin" ]; then
    HOST_TRIPLE=x86_64-apple-darwin
    ARTIFACT=solana-bpf-tools-osx.tar.bz2
else
    HOST_TRIPLE=x86_64-unknown-linux-gnu
    ARTIFACT=solana-bpf-tools-linux.tar.bz2
fi

cd "$(dirname "$0")"

rm -rf out
mkdir -p out
pushd out

git clone --single-branch --branch bpf-tools-v1.3 https://github.com/solana-labs/rust.git
echo "$( cd rust && git rev-parse HEAD )  https://github.com/solana-labs/rust.git" >> version.md

git clone --recurse-submodules --single-branch --branch bpf-tools-v1.3 https://github.com/solana-labs/rust-bpf-sysroot.git
echo "$( cd rust-bpf-sysroot && git rev-parse HEAD )  https://github.com/solana-labs/rust-bpf-sysroot.git" >> version.md

git clone --single-branch --branch rust-1.50.0 https://github.com/rust-lang/cargo.git
echo "$( cd cargo && git rev-parse HEAD )  https://github.com/rust-lang/cargo.git" >> version.md

pushd rust
./build.sh --llvm
RUST_DIR=$PWD
popd

pushd rust-bpf-sysroot
./test/build.sh "${RUST_DIR}/build/${HOST_TRIPLE}"
popd

pushd cargo
OPENSSL_STATIC=1 cargo build --release
popd

# Copy rust build products
mkdir -p deploy/rust/lib/rustlib/bpfel-unknown-unknown/lib
cp version.md deploy/
cp -R rust/build/${HOST_TRIPLE}/stage1/{bin,lib} deploy/rust/
cp -R rust-bpf-sysroot/test/dependencies/xargo/lib/rustlib/bpfel-unknown-unknown/lib/*.rlib deploy/rust/lib/rustlib/bpfel-unknown-unknown/lib/
cp -R cargo/target/release/cargo deploy/rust/bin/
rm -rf deploy/rust/lib/rustlib/src

# Copy llvm build products
mkdir -p deploy/llvm/{bin,lib}
while IFS= read -r f
do
    cp -R "rust/build/${HOST_TRIPLE}/llvm/build/bin/${f}" deploy/llvm/bin/
done < <(cat <<EOF
clang
clang++
clang-11
clang-cl
clang-cpp
ld.lld
ld64.lld
llc
lld
lld-link
llvm-ar
llvm-objcopy
llvm-objdump
llvm-readelf
llvm-readobj
EOF
         )
cp -R rust/build/${HOST_TRIPLE}/llvm/build/lib/clang deploy/llvm/lib/

tar -C deploy -jcf ${ARTIFACT} .
popd

# Build linux binaries on macOS in docker
if [[ "$(uname)" == "Darwin" ]] && [[ $# == 1 ]] && [[ "$1" == "--docker" ]] ; then
    docker system prune -a -f
    docker build -t solanalabs/bpf-tools .
    id=$(docker create solanalabs/bpf-tools /build.sh)
    docker cp build.sh "${id}:/"
    docker start -a "${id}"
    docker cp "${id}:out/solana-bpf-tools-linux.tar.bz2" out/
fi
