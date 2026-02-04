#!/usr/bin/env bash
set -ex

WITH_NIX=
case "$1" in
    --nix)
        WITH_NIX="--nix"
        shift
        ;;
esac

function build_newlib() {
    mkdir -p newlib_build_"$1"
    mkdir -p newlib_"$1"
    pushd newlib_build_"$1"

    local c_flags="-O2"
    if [[ "$1" != "v0" ]] ; then
      c_flags="${c_flags} -mcpu=$1"
    fi

    CFLAGS="${c_flags}" \
    CC="${OUT_DIR}/rust/build/${HOST_TRIPLE}/llvm/bin/clang" \
      AR="${OUT_DIR}/rust/build/${HOST_TRIPLE}/llvm/bin/llvm-ar" \
      RANLIB="${OUT_DIR}/rust/build/${HOST_TRIPLE}/llvm/bin/llvm-ranlib" \
      ../newlib/newlib/configure --target=sbf-solana-solana --host=sbf-solana --build="${HOST_TRIPLE}" --prefix="${OUT_DIR}/newlib_$1"
    make install
    popd
}

function copy_newlib() {
    local folder_name=""
    if [[ "$1" != "v0" ]] ; then
        folder_name="$1"
    fi

    mkdir -p deploy/llvm/lib/sbpf"${folder_name}"
    mkdir -p deploy/llvm/sbpf"${folder_name}"
    cp -R newlib_"$1"/sbf-solana/lib/lib{c,m}.a deploy/llvm/lib/sbpf"${folder_name}"/
    cp -R newlib_"$1"/sbf-solana/include deploy/llvm/sbpf"${folder_name}"/
}

unameOut="$(uname -s)"
case "${unameOut}" in
    Darwin*)
        EXE_SUFFIX=
        if [[ "$(uname -m)" == "arm64" ]] || [[ "$(uname -m)" == "aarch64" ]]; then
            HOST_TRIPLE=aarch64-apple-darwin
            ARTIFACT=platform-tools-osx-aarch64.tar.bz2
        else
            HOST_TRIPLE=x86_64-apple-darwin
            ARTIFACT=platform-tools-osx-x86_64.tar.bz2
        fi;;
    MINGW*)
        EXE_SUFFIX=.exe
        HOST_TRIPLE=x86_64-pc-windows-msvc
        ARTIFACT=platform-tools-windows-x86_64.tar.bz2;;
    Linux* | *)
        EXE_SUFFIX=
        if [[ "$(uname -m)" == "arm64" ]] || [[ "$(uname -m)" == "aarch64" ]]; then
            HOST_TRIPLE=aarch64-unknown-linux-gnu
            ARTIFACT=platform-tools-linux-aarch64.tar.bz2
        else
            HOST_TRIPLE=x86_64-unknown-linux-gnu
            ARTIFACT=platform-tools-linux-x86_64.tar.bz2
        fi
esac

cd "$(dirname "$0")"
OUT_DIR="$(realpath ./)/${1:-out}"

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"
pushd "${OUT_DIR}"

git clone --single-branch --branch mac-mig --recurse-submodules --shallow-submodules https://github.com/joncinque/rust.git
echo "$( cd rust && git rev-parse HEAD )  https://github.com/anza-xyz/rust.git" >> version.md

git clone --single-branch --branch solana-tools-v1.53 https://github.com/anza-xyz/cargo.git
echo "$( cd cargo && git rev-parse HEAD )  https://github.com/anza-xyz/cargo.git" >> version.md

pushd rust
if [[ "${HOST_TRIPLE}" == "x86_64-pc-windows-msvc" ]] ; then
    # Do not build lldb on Windows
    sed -i -e 's#enable-projects = \"clang;lld;lldb\"#enable-projects = \"clang;lld\"#g' bootstrap.toml
fi

if [[ "${HOST_TRIPLE}" == *"apple"* ]]; then
    ./src/llvm-project/lldb/scripts/macos-setup-codesign.sh
fi

./build.sh $WITH_NIX
popd

pushd cargo
if [[ "${WITH_NIX}" == "--nix" ]] ; then
    # NIX_SSL_CERT_FILE is required for Mac builds
    nix-shell shell.nix --pure --keep NIX_SSL_CERT_FILE --run "cargo build --release"
else
    if [[ "${HOST_TRIPLE}" == "x86_64-unknown-linux-gnu" ]] ; then
        OPENSSL_STATIC=1 OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu OPENSSL_INCLUDE_DIR=/usr/include/openssl cargo build --release
    else
        OPENSSL_STATIC=1 cargo build --release
    fi
fi
popd

if [[ "${HOST_TRIPLE}" != "x86_64-pc-windows-msvc" ]] ; then
    git clone --single-branch --branch solana-tools-v1.53 https://github.com/anza-xyz/newlib.git
    echo "$( cd newlib && git rev-parse HEAD )  https://github.com/anza-xyz/newlib.git" >> version.md

    build_newlib "v0"
    build_newlib "v1"
    build_newlib "v2"
    build_newlib "v3"
fi

# Copy rust build products
mkdir -p deploy/rust
cp version.md deploy/
cp -R "rust/build/${HOST_TRIPLE}/stage1/bin" deploy/rust/
cp -R "cargo/target/release/cargo${EXE_SUFFIX}" deploy/rust/bin/
mkdir -p deploy/rust/lib/rustlib/
cp -R "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/${HOST_TRIPLE}" deploy/rust/lib/rustlib/
cp -R "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/sbpf-solana-solana" deploy/rust/lib/rustlib/
cp -R "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/sbpfv1-solana-solana" deploy/rust/lib/rustlib/
cp -R "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/sbpfv2-solana-solana" deploy/rust/lib/rustlib/
cp -R "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/sbpfv3-solana-solana" deploy/rust/lib/rustlib/
find . -maxdepth 6 -type f -path "./rust/build/${HOST_TRIPLE}/stage1/lib/*" -exec cp {} deploy/rust/lib \;
mkdir -p deploy/rust/lib/rustlib/src/rust
cp "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/src/rust/Cargo.lock" deploy/rust/lib/rustlib/src/rust
cp -R "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/src/rust/library" deploy/rust/lib/rustlib/src/rust

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
clang-20
ld.lld
ld64.lld
llc
lld
lld-link
lldb
lldb-vscode
llvm-ar
llvm-objcopy
llvm-objdump
llvm-readelf
llvm-readobj
EOF
         )
cp -R "rust/build/${HOST_TRIPLE}/llvm/build/lib/clang" deploy/llvm/lib/
if [[ "${HOST_TRIPLE}" != "x86_64-pc-windows-msvc" ]] ; then
    cp -R newlib_v0/sbf-solana/lib/lib{c,m}.a deploy/llvm/lib/
    cp -R newlib_v0/sbf-solana/include deploy/llvm/

    copy_newlib "v0"
    copy_newlib "v1"
    copy_newlib "v2"
    copy_newlib "v3"

    cp -R rust/src/llvm-project/lldb/scripts/solana/* deploy/llvm/bin/
    cp -R rust/build/${HOST_TRIPLE}/llvm/lib/liblldb.* deploy/llvm/lib/
    if [[ "${HOST_TRIPLE}" == "x86_64-unknown-linux-gnu" || "${HOST_TRIPLE}" == "aarch64-unknown-linux-gnu" ]]; then
        cp -R rust/build/${HOST_TRIPLE}/llvm/local/lib/python* deploy/llvm/lib
    else
        cp -R rust/build/${HOST_TRIPLE}/llvm/lib/python* deploy/llvm/lib/
    fi
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
    if [[ -f "./deploy/llvm/bin/${f}${EXE_SUFFIX}" ]] ; then
        "./deploy/llvm/bin/${f}${EXE_SUFFIX}" --version
    fi
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
solana-lldb
EOF
         )

tar -C deploy -jcf ${ARTIFACT} .
rm -rf deploy

popd

mv "${OUT_DIR}/${ARTIFACT}" .

# Build linux binaries on macOS in docker
if [[ "$(uname)" == "Darwin" ]] && [[ $# == 1 ]] && [[ "$1" == "--docker" ]] ; then
    docker system prune -a -f
    docker build -t solanalabs/platform-tools .
    id=$(docker create solanalabs/platform-tools /build.sh "${OUT_DIR}")
    docker cp build.sh "${id}:/"
    docker start -a "${id}"
    docker cp "${id}:${OUT_DIR}/solana-sbf-tools-linux-x86_64.tar.bz2" "${OUT_DIR}"
fi
