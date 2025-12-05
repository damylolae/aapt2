#!/usr/bin/env bash
set -euo pipefail

# Must be set by CI
if [[ -z "${NDK_TOOLCHAIN:-}" ]]; then
    echo "NDK_TOOLCHAIN is not set!"
    exit 1
fi

ARCH="${1:-}"
case "$ARCH" in
  x86_64)   TRIPLE=x86_64-linux-android21     ; API=21 ;;
  i686)     TRIPLE=i686-linux-android16       ; API=16 ;;
  aarch64)  TRIPLE=aarch64-linux-android21    ; API=21 ;;
  armv7a)   TRIPLE=armv7a-linux-androideabi16 ; API=16 ;;
  *) echo "Unknown arch: $ARCH" ; exit 1 ;;
esac

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$ROOT/build_$ARCH"
DIST="$ROOT/dist/$ARCH"

rm -rf "$BUILD" "$DIST"
mkdir -p "$BUILD" "$DIST"
cd "$BUILD"

echo "Building aapt2 for $ARCH → $TRIPLE (API $API)"

# Build host protoc once
if ! command -v protoc >/dev/null 2>&1; then
    echo "Building host protoc..."
    cd "$ROOT/src/protobuf"
    ./autogen.sh >/dev/null
    ./configure --quiet
    make -j$(nproc)
    sudo make install
    sudo ldconfig || true
fi

# Apply patches
cd "$ROOT"
git apply patches/*.patch --whitespace=fix 2>/dev/null || true

# CMake – this is the correct way in 2025
cmake "$ROOT" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="${NDK_TOOLCHAIN}/bin/${TRIPLE}-clang" \
    -DCMAKE_CXX_COMPILER="${NDK_TOOLCHAIN}/bin/${TRIPLE}-clang++" \
    -DCMAKE_SYSROOT="${NDK_TOOLCHAIN}/sysroot" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DPROTOC_PATH="$(command -v protoc)" \
    -DANDROID_ABI="$ARCH"

ninja -j$(nproc)

"${NDK_TOOLCHAIN}/bin/llvm-strip" --strip-unneeded aapt2
mv aapt2 "$DIST/"
echo "Built: $DIST/aapt2"
