#!/usr/bin/env bash
set -ex

unameOut="$(uname -s)"
case "${unameOut}" in
    Darwin*)
        EXE_SUFFIX=
        HOST_TRIPLE=x86_64-apple-darwin
        ARTIFACT=solana-bpf-tools-osx.tar.bz2;;
    MINGW*)
        EXE_SUFFIX=.exe
        HOST_TRIPLE=x86_64-pc-windows-msvc
        ARTIFACT=solana-bpf-tools-windows.tar.bz2;;
    Linux* | *)
        EXE_SUFFIX=
        HOST_TRIPLE=x86_64-unknown-linux-gnu
        ARTIFACT=solana-bpf-tools-linux.tar.bz2
esac

cd "$(dirname "$0")"
OUT_DIR="$(readlink -f ${1:-out})"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"
pushd "${OUT_DIR}"

git clone --single-branch --branch bpf-tools-v1.20 https://github.com/solana-labs/rust.git
echo "$( cd rust && git rev-parse HEAD )  https://github.com/solana-labs/rust.git" >> version.md

git clone --single-branch --branch rust-1.56.0 https://github.com/rust-lang/cargo.git
echo "$( cd cargo && git rev-parse HEAD )  https://github.com/rust-lang/cargo.git" >> version.md

pushd rust
./build.sh
popd

pushd cargo
OPENSSL_STATIC=1 cargo build --release
popd

if [[ "${HOST_TRIPLE}" != "x86_64-pc-windows-msvc" ]] ; then
    git clone --single-branch --branch bpf-tools-v1.20 https://github.com/solana-labs/newlib.git
    echo "$( cd newlib && git rev-parse HEAD )  https://github.com/solana-labs/newlib.git" >> version.md
    mkdir -p newlib_build
    mkdir -p newlib_install
    pushd newlib_build
    CC="${OUT_DIR}/rust/build/${HOST_TRIPLE}/llvm/bin/clang" \
      AR="${OUT_DIR}/rust/build/${HOST_TRIPLE}/llvm/bin/llvm-ar" \
      RANLIB="${OUT_DIR}/rust/build/${HOST_TRIPLE}/llvm/bin/llvm-ranlib" \
      ../newlib/newlib/configure --target=sbf-solana-solana --host=sbf-solana --build="${HOST_TRIPLE}" --prefix="${OUT_DIR}/newlib_install"
    make install
    popd
fi

# Copy rust build products
mkdir -p deploy/rust
cp version.md deploy/
cp -R "rust/build/${HOST_TRIPLE}/stage1/bin" deploy/rust/
cp -R "cargo/target/release/cargo${EXE_SUFFIX}" deploy/rust/bin/
mkdir -p deploy/rust/lib/rustlib/
cp -R "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/${HOST_TRIPLE}" deploy/rust/lib/rustlib/
cp -R "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/bpfel-unknown-unknown" deploy/rust/lib/rustlib/
find . -maxdepth 6 -type f -path "./rust/build/${HOST_TRIPLE}/stage1/lib/*" -exec cp {} deploy/rust/lib \;

# Copy llvm build products
mkdir -p deploy/llvm/{bin,lib}
while IFS= read -r f
do
    bin_file="rust/build/${HOST_TRIPLE}/llvm/build/bin/${f}${EXE_SUFFIX}"
    if [[ -f "$bin_file" ]] ; then
        cp -R "$bin_file" deploy/llvm/bin/
    fi
done < <(cat <<EOF
clang
clang++
clang-cl
clang-cpp
clang-13
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
cp -R "rust/build/${HOST_TRIPLE}/llvm/build/lib/clang" deploy/llvm/lib/
if [[ "${HOST_TRIPLE}" != "x86_64-pc-windows-msvc" ]] ; then
    cp -R newlib_install/sbf-solana/lib/lib{c,m}.a deploy/llvm/lib/
    cp -R newlib_install/sbf-solana/include deploy/llvm/
fi

# Check the Rust binaries
while IFS= read -r f
do
    "./deploy/rust/bin/${f}${EXE_SUFFIX}" --version
done < <(cat <<EOF
cargo
rustc
rustdoc
EOF
         )
# Check the LLVM binaries
while IFS= read -r f
do
    "./deploy/llvm/bin/${f}${EXE_SUFFIX}" --version
done < <(cat <<EOF
clang
clang++
clang-cl
clang-cpp
ld.lld
llc
lld-link
llvm-ar
llvm-objcopy
llvm-objdump
llvm-readelf
llvm-readobj
EOF
         )

tar -C deploy -jcf ${ARTIFACT} .
popd

# Build linux binaries on macOS in docker
if [[ "$(uname)" == "Darwin" ]] && [[ $# == 1 ]] && [[ "$1" == "--docker" ]] ; then
    docker system prune -a -f
    docker build -t solanalabs/bpf-tools .
    id=$(docker create solanalabs/bpf-tools /build.sh "${OUT_DIR}")
    docker cp build.sh "${id}:/"
    docker start -a "${id}"
    docker cp "${id}:${OUT_DIR}/solana-bpf-tools-linux.tar.bz2" "${OUT_DIR}"
fi
