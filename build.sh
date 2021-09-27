#!/usr/bin/env bash
set -ex

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)
        EXE_SUFFIX=
        HOST_TRIPLE=x86_64-unknown-linux-gnu
        ARTIFACT=solana-bpf-tools-linux.tar.bz2;;
    Darwin*)
        EXE_SUFFIX=
        HOST_TRIPLE=x86_64-apple-darwin
        ARTIFACT=solana-bpf-tools-osx.tar.bz2;;
    MINGW*)
        EXE_SUFFIX=.exe
        HOST_TRIPLE=x86_64-pc-windows-msvc
        ARTIFACT=solana-bpf-tools-windows.tar.bz2;;
    *)
        EXE_SUFFIX=
        HOST_TRIPLE=x86_64-unknown-linux-gnu
        ARTIFACT=solana-bpf-tools-linux.tar.bz2
esac

cd "$(dirname "$0")"

rm -rf out
mkdir -p out
pushd out

git clone --single-branch --branch bpf-tools-v1.16 https://github.com/solana-labs/rust.git
echo "$( cd rust && git rev-parse HEAD )  https://github.com/solana-labs/rust.git" >> version.md

git clone --single-branch --branch rust-1.54.0 https://github.com/rust-lang/cargo.git
echo "$( cd cargo && git rev-parse HEAD )  https://github.com/rust-lang/cargo.git" >> version.md

pushd rust
./build.sh
popd

pushd cargo
OPENSSL_STATIC=1 cargo build --release
popd

# Copy rust build products
mkdir -p deploy/rust
cp version.md deploy/
cp -R rust/build/${HOST_TRIPLE}/stage1/bin deploy/rust/
mkdir -p deploy/rust/lib/rustlib/
cp -R rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/${HOST_TRIPLE} deploy/rust/lib/rustlib/
cp -R rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/bpfel-unknown-unknown deploy/rust/lib/rustlib/
cp -R cargo/target/release/cargo"${EXE_SUFFIX}" deploy/rust/bin/

# Copy llvm build products
mkdir -p deploy/llvm/{bin,lib}
while IFS= read -r f
do
    cp -R "rust/build/${HOST_TRIPLE}/llvm/build/bin/${f}${EXE_SUFFIX}" deploy/llvm/bin/
done < <(cat <<EOF
clang
clang++
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
