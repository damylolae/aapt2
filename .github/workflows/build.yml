name: Build aapt2

on:
  push:
    branches: [ main, dev ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        arch: [x86_64, i686, aarch64, armv7a]

    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Install dependencies
        run: sudo apt-get update && sudo apt-get install -y ninja-build autoconf automake libtool pkg-config

      - name: Setup NDK r27
        uses: nttld/setup-ndk@v1
        id: ndk
        with:
          ndk-version: r27

      - name: Export toolchain paths
        run: |
          TOOLCHAIN="${{ steps.ndk.outputs.ndk-path }}/toolchains/llvm/prebuilt/linux-x86_64"
          echo "NDK_TOOLCHAIN=$TOOLCHAIN" >> $GITHUB_ENV
          echo "PATH=$TOOLCHAIN/bin:$PATH" >> $GITHUB_ENV

      - name: Build aapt2 ${{ matrix.arch }}
        run: |
          chmod +x ./build.sh
          ./build.sh ${{ matrix.arch }}

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: aapt2-${{ matrix.arch }}
          path: dist/${{ matrix.arch }}/aapt2
