#!/usr/bin/env bash
set -ex

unameOut="$(uname -s)"
case "${unameOut}" in
    Darwin*)
        EXE_SUFFIX=
        if [[ "$(uname -m)" == "arm64" ]] ; then
            HOST_TRIPLE=aarch64-apple-darwin
            ARTIFACT=platform-tools-osx-aarch64.tar.bz2
        else
            HOST_TRIPLE=x86_64-apple-darwin
            ARTIFACT=platform-tools-osx-x86_64.tar.bz2
        fi;;
    FreeBSD*)
        EXE_SUFFIX=
        if [[ "$(uname -m)" == "arm64" ]] ; then
            HOST_TRIPLE=aarch64-unknown-freebsd
            ARTIFACT=platform-tools-freebsd-aarch64.tar.bz2
        else
            HOST_TRIPLE=x86_64-unknown-freebsd
            ARTIFACT=platform-tools-freebsd-x86_64.tar.bz2
        fi;;
    MINGW*)
        EXE_SUFFIX=.exe
        HOST_TRIPLE=x86_64-pc-windows-msvc
        ARTIFACT=platform-tools-windows-x86_64.tar.bz2;;
    Linux* | *)
        EXE_SUFFIX=
        if [[ "$(uname -m)" == "arm64" ]] ; then
            HOST_TRIPLE=aarch64-unknown-linux-gnu
            ARTIFACT=platform-tools-linux-aarch64.tar.bz2
        else
            HOST_TRIPLE=x86_64-unknown-linux-gnu
            ARTIFACT=platform-tools-linux-x86_64.tar.bz2
        fi
esac

# note: directory must exist for realpath on *BSD
cd "$(dirname "$0")"
OUT_DIR="${1:-out}"
if [[ -e "${OUT_DIR}" ]] ; then
    OUT_DIR="$(realpath "${OUT_DIR}")"
    rm -rf -- "${OUT_DIR}"
fi

mkdir -p -- "${OUT_DIR}"
OUT_DIR="$(realpath "${OUT_DIR}")"
pushd -- "${OUT_DIR}"

GIT_BRANCH='solana-tools-v1.38'

function git_clone() {
    local REPO="${1}"
    local URL="https://github.com/solana-labs/${REPO}.git"
    git clone --single-branch --branch "${GIT_BRANCH}" "${URL}"
    local COMMIT="$(git -C "${REPO}" rev-parse HEAD)"
    echo "${COMMIT}  ${URL}" >> version.md
}

git_clone rust
git_clone cargo

(   # sub shell
    cd rust
    if [[ "${HOST_TRIPLE}" == "x86_64-pc-windows-msvc" ]] ; then
        # Do not build lldb on Windows
	sed -i -e 's#enable-projects = "clang;lld;lldb"#enable-projects = "clang;lld"#g' config.toml
    elif [[ "${HOST_TRIPLE}" == *-"unknown-freebsd" ]] ; then
	# Fixup build.sh in solana-labs/rust until FreeBSD added there
	fgrep -q 'HOST_TRIPLE=x86_64-unknown-freebsd' build.sh ||
	ed build.sh <<-'EOF'
	/HOST_TRIPLE=x86_64-unknown-linux-gnu/i
	    FreeBSD-amd64*) HOST_TRIPLE=x86_64-unknown-freebsd;;
	    FreeBSD-arm64*) HOST_TRIPLE=aarch64-unknown-freebsd;;
	.
	w
	EOF
        # Use swig40 instead of default swig 4.1.2 on FreeBSD due to
	# broken %nothreadallow / %clearnothreadallow directives
	ed config.toml <<-'EOF'
	/^\[llvm\]/a

	# Custom CMake defines to set when building LLVM.
	build-config = { SWIG_EXECUTABLE = "/usr/local/bin/swig40" }
	.
	+1,$g/^ *build-config *=/d
	w
	EOF
    fi
    ./build.sh
)

(   # sub shell
    cd cargo
    export OPENSSL_STATIC=1
    if [[ "${HOST_TRIPLE}" == "x86_64-unknown-linux-gnu" ]] ; then
        export OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu
	export OPENSSL_INCLUDE_DIR=/usr/include/openssl
    fi
    cargo build --release
)

if [[ "${HOST_TRIPLE}" != "x86_64-pc-windows-msvc" ]] ; then
    git_clone newlib
    mkdir -p newlib_{build,install}
    (   # sub shell
        cd newlib_build
	(   # sub sub shell
	    export CC="${OUT_DIR}/rust/build/${HOST_TRIPLE}/llvm/bin/clang"
	    export AR="${OUT_DIR}/rust/build/${HOST_TRIPLE}/llvm/bin/llvm-ar"
	    export RANLIB="${OUT_DIR}/rust/build/${HOST_TRIPLE}/llvm/bin/llvm-ranlib"
	    [[ "${HOST_TRIPLE}" == *-freebsd ]] && export CC_FOR_BUILD='cc'
	    ARGS=(
	    --target=sbf-solana-solana
	    --host=sbf-solana
	    --build="${HOST_TRIPLE}"
	    --prefix="${OUT_DIR}/newlib_install"
	    )
	    ../newlib/newlib/configure "${ARGS[@]}"
	)
	MAKE='make'
	[[ "${HOST_TRIPLE}" == *-freebsd ]] && MAKE='gmake'
	"${MAKE}" install
    )
fi

# Copy rust build products
mkdir -p deploy/rust
cp version.md deploy/
cp -R "rust/build/${HOST_TRIPLE}/stage1/bin" deploy/rust/
cp -R "cargo/target/release/cargo${EXE_SUFFIX}" deploy/rust/bin/
mkdir -p deploy/rust/lib/rustlib/
cp -R "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/${HOST_TRIPLE}" deploy/rust/lib/rustlib/
cp -R "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/sbf-solana-solana" deploy/rust/lib/rustlib/
find . -maxdepth 6 -type f -path "./rust/build/${HOST_TRIPLE}/stage1/lib/*" -exec cp {} deploy/rust/lib \;
mkdir -p deploy/rust/lib/rustlib/src/rust
cp "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/src/rust/Cargo.lock" deploy/rust/lib/rustlib/src/rust
cp -R "rust/build/${HOST_TRIPLE}/stage1/lib/rustlib/src/rust/library" deploy/rust/lib/rustlib/src/rust

# Copy llvm build products
mkdir -p deploy/llvm/{bin,lib}
FILES=(
clang
clang++
clang-cl
clang-cpp
clang-15
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
)
for FILE in "${FILES[@]}"; do
    bin_file="rust/build/${HOST_TRIPLE}/llvm/build/bin/${FILE}${EXE_SUFFIX}"
    if [[ -f "$bin_file" ]] ; then
        cp -R "$bin_file" deploy/llvm/bin/
    fi
done

cp -R "rust/build/${HOST_TRIPLE}/llvm/build/lib/clang" deploy/llvm/lib/
if [[ "${HOST_TRIPLE}" != "x86_64-pc-windows-msvc" ]] ; then
    cp -R newlib_install/sbf-solana/lib/lib{c,m}.a deploy/llvm/lib/
    cp -R newlib_install/sbf-solana/include deploy/llvm/
    cp -R rust/src/llvm-project/lldb/scripts/solana/* deploy/llvm/bin/
    cp -R rust/build/${HOST_TRIPLE}/llvm/lib/liblldb.* deploy/llvm/lib/
    cp -R rust/build/${HOST_TRIPLE}/llvm/lib/python* deploy/llvm/lib/
fi

# Check the Rust binaries
FILES=(
cargo
rustc
rustdoc
)
for FILE in "${FILES[@]}"; do
    "./deploy/rust/bin/${FILE}${EXE_SUFFIX}" --version
done

# Check the LLVM binaries
FILES=(
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
)
for FILE in "${FILES[@]}"; do
    if [[ -f "./deploy/llvm/bin/${FILE}${EXE_SUFFIX}" ]] ; then
        "./deploy/llvm/bin/${FILE}${EXE_SUFFIX}" --version
    fi
done

tar -C deploy -jcf ${ARTIFACT} .
rm -rf deploy

# Package LLVM binaries for Move project
MOVE_DEV_TAR="${ARTIFACT/platform-tools/move-dev}"
mkdir move-dev
if [[ "${HOST_TRIPLE}" == "x86_64-pc-windows-msvc" ]] ; then
    rm -f rust/build/"${HOST_TRIPLE}"/llvm/bin/llvm-{ranlib,lib,dlltool}.exe}
fi
cp -R "rust/build/${HOST_TRIPLE}/llvm/"{bin,include,lib} move-dev/
tar -jcf "${MOVE_DEV_TAR}" move-dev

popd

mv "${OUT_DIR}/${ARTIFACT}" .
mv "${OUT_DIR}/${MOVE_DEV_TAR}" .

# Build linux binaries on macOS in docker
if [[ "$(uname)" == "Darwin" ]] && [[ $# == 1 ]] && [[ "$1" == "--docker" ]] ; then
    docker system prune -a -f
    docker build -t solanalabs/platform-tools .
    id=$(docker create solanalabs/platform-tools /build.sh "${OUT_DIR}")
    docker cp build.sh "${id}:/"
    docker start -a "${id}"
    docker cp "${id}:${OUT_DIR}/solana-sbf-tools-linux-x86_64.tar.bz2" "${OUT_DIR}"
fi
