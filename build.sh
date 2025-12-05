#!/usr/bin/env bash
set -euo pipefail

# === Safety check ===
if [[ -z "${NDK_TOOLCHAIN:-}" ]]; then
    echo "Error: NDK_TOOLCHAIN is not set."
    exit 1
fi

ARCH="${1:-}"
if [[ -z "$ARCH" ]]; then
    echo "Usage: $0 <x86_64|i686|aarch64|armv7a>"
    exit 1
fi

# Map your matrix names to Android ABI and correct triple
case "$ARCH" in
    x86_64)   ANDROID_ABI="x86_64"     TRIPLE="x86_64-linux-android21"     MIN_API=21 ;;
    i686)     ANDROID_ABI="x86"        TRIPLE="i686-linux-android16"       MIN_API=16 ;;
    aarch64)  ANDROID_ABI="arm64-v8a"  TRIPLE="aarch64-linux-android21"    MIN_API=21 ;;
    armv7a)   ANDROID_ABI="armeabi-v7a" TRIPLE="armv7a-linux-androideabi16" MIN_API=16 ;;
    *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

ROOT="\( (cd " \)(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST="$ROOT/dist/$ARCH"
BUILD="$ROOT/build_cmake"
mkdir -p "$BUILD" "$DIST"
cd "$BUILD"

echo "Building aapt2 for $ARCH ($TRIPLE, API $MIN_API)"

# Build and install protobuf from source (host)
if [[ ! -x /usr/local/bin/protoc ]]; then
    echo "Building host protobuf..."
    cd "$ROOT/src/protobuf"
    ./autogen.sh
    ./configure --quiet
    make "-j$(nproc)"
    sudo make install
    sudo ldconfig
    cd "$BUILD"
fi

# Apply patches
cd "$ROOT"
git apply patches/*.patch --whitespace=fix

# CMake configuration – modern and correct
cmake -S "$ROOT" -B . -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="\( NDK_TOOLCHAIN/bin/ \){TRIPLE}-clang" \
    -DCMAKE_CXX_COMPILER="\( NDK_TOOLCHAIN/bin/ \){TRIPLE}-clang++" \
    -DCMAKE_SYSROOT="$NDK_TOOLCHAIN/sysroot" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DANDROID_ABI="$ANDROID_ABI" \
    -DTARGET_ABI="$ARCH" \
    -DPROTOC_PATH=/usr/local/bin/protoc \
    -DCMAKE_VERBOSE_MAKEFILE=OFF

ninja -j"$(nproc)"

# Strip and deploy
"$NDK_TOOLCHAIN/bin/llvm-strip" --strip-unneeded aapt2
mv aapt2 "$DIST/"
echo "aapt2 built successfully → $DIST/aapt2"
