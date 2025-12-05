#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${NDK_TOOLCHAIN:-}" ]]; then
  echo "NDK_TOOLCHAIN not set"
  exit 1
fi

ARCH="$1"
case "$ARCH" in
  x86_64)   TRIPLE=x86_64-linux-android21     ; API=21 ;;
  i686)     TRIPLE=i686-linux-android16          ; API=16 ;;   # note: i686, not i686-linux-android16 on some NDKs
  aarch64)  TRIPLE=aarch64-linux-android21    ; API=21 ;;
  armv7a)   TRIPLE=armv7a-linux-androideabi16 ; API=16 ;;
  *) echo "Bad arch"; exit 1 ;;
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
git apply patches/*.patch --whitespace=fix || true

# THIS IS THE MAGIC LINE THAT FIXES THE "not a full path" ERROR
cmake "$ROOT" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_COMPILER=${TRIPLE}-clang \
  -DCMAKE_CXX_COMPILER=${TRIPLE}-clang++ \
  -DCMAKE_SYSROOT="$NDK_TOOLCHAIN/sysroot" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DPROTOC_PATH=$(command -v protoc) \
  -DANDROID_ABI="$ARCH"

ninja -j$(nproc)

"$NDK_TOOLCHAIN/bin/llvm-strip" --strip-unneeded aapt2
mv aapt2 "$DIST/"
echo "SUCCESS → $DIST/aapt2"
