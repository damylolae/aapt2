#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Safety checks
# -------------------------------
if [[ -z "${NDK_TOOLCHAIN:-}" ]]; then
    echo "Error: NDK_TOOLCHAIN environment variable is not set."
    exit 1
fi

ARCH="${1:-}"
if [[ -z "$ARCH" ]]; then
    echo "Usage: $0 <x86_64|i686|aarch64|armv7a>"
    exit 1
fi

# -------------------------------
# Architecture → triple + ABI mapping (2025 correct)
# -------------------------------
case "$ARCH" in
    x86_64)
        ANDROID_ABI="x86_64"
        TRIPLE="x86_64-linux-android21"
        MIN_API=21
        ;;
    i686)
        ANDROID_ABI="x86"
        TRIPLE="i686-linux-android16"
        MIN_API=16
        ;;
    aarch64)
        ANDROID_ABI="arm64-v8a"
        TRIPLE="aarch64-linux-android21"
        MIN_API=21
        ;;
    armv7a)
        ANDROID_ABI="armeabi-v7a"
        TRIPLE="armv7a-linux-androideabi16"
        MIN_API=16
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# -------------------------------
# Paths
# -------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build_cmake"
DIST_DIR="$ROOT/dist/$ARCH"

mkdir -p "$BUILD_DIR" "$DIST_DIR"
cd "$BUILD_DIR"

echo "Building aapt2 for $ARCH → $TRIPLE (API $MIN_API)"

# -------------------------------
# Build & install host protoc (only once)
# -------------------------------
if ! command -v protoc &>/dev/null; then
    echo "Building host protobuf compiler..."
    cd "$ROOT/src/protobuf"
    ./autogen.sh >/dev/null
    ./configure --quiet
    make -j"$(nproc)"
    sudo make install
    sudo ldconfig || true
    cd "$BUILD_DIR"
fi

# -------------------------------
# Apply patches
# -------------------------------
cd "$ROOT"
for p in patches/*.patch; do
    git apply "$p" --whitespace=fix || true
done

# -------------------------------
# CMake configuration – this is the only correct way in 2025
# -------------------------------
cmake "$ROOT" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$NDK_TOOLCHAIN/bin/${TRIPLE}-clang" \
    -DCMAKE_CXX_COMPILER="$NDK_TOOLCHAIN/bin/${TRIPLE}-clang++" \
    -DCMAKE_SYSROOT="$NDK_TOOLCHAIN/sysroot" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DANDROID_ABI="$ANDROID_ABI" \
    -DTARGET_ABI="$ARCH" \
    -DPROTOC_PATH="$(command -v protoc)" \
    -DCMAKE_VERBOSE_MAKEFILE=OFF

# -------------------------------
# Build & strip
# -------------------------------
ninja -j"$(nproc)"

"$NDK_TOOLCHAIN/bin/llvm-strip" --strip-unneeded aapt2

mv aapt2 "$DIST_DIR/"
echo ""
echo "SUCCESS! aapt2 built → $DIST_DIR/aapt2"
echo "Size: $(du -h "$DIST_DIR/aapt2" | cut -f1)"
