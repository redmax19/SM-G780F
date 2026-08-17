#!/bin/bash
# ============================================================================
#  KernelSU-Next + SuSFS v2.0.0 — Galaxy S20 (Exynos 990 / universal9830)
#  Unified build for all S20 Exynos variants.
#
#  Usage:   ./build.sh -m <g780f|g985f|g980f|g988b|g986b|g981b>
# ============================================================================
set -e

MODEL="g780f"
while getopts "m:" o; do case $o in m) MODEL=$OPTARG ;; esac; done
case "$MODEL" in
  g985f) BASE=exynos9830-y2slte_defconfig ;;
  g780f) BASE=exynos9830-r8slte_defconfig ;;
  g988b) BASE=exynos9830-z3sxxx_defconfig ;;
  g986b) BASE=exynos9830-y2sxxx_defconfig ;;
  g981b) BASE=exynos9830-x1sxxx_defconfig ;;
  *)   echo "Unknown model '$MODEL' (use g780f|g985f|g980f|g988b|g986b|g981b)"; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")" && pwd)"
CLANG_DIR="$(realpath "${CLANG_DIR:-$ROOT/../tc/clang10}")"
GCC_DIR="$(realpath "${GCC_DIR:-$ROOT/../tc/gcc49}")"
GCC32_DIR="$(realpath "${GCC32_DIR:-$ROOT/../tc/gcc32}")"

[ -x "$CLANG_DIR/bin/clang" ] || { echo "ERROR: clang não encontrado em $CLANG_DIR"; exit 1; }
[ -x "$GCC_DIR/bin/aarch64-linux-android-as" ] || { echo "ERROR: GCC 64-bit não encontrado em $GCC_DIR"; exit 1; }
[ -x "$GCC32_DIR/bin/arm-linux-androideabi-as" ] || { echo "ERROR: GCC 32-bit não encontrado em $GCC32_DIR"; exit 1; }

export PATH="$CLANG_DIR/bin:$GCC_DIR/bin:$GCC32_DIR/bin:$PATH"
export ARCH=arm64 LC_ALL=C

# Samsung Kconfig macros exigidas para evitar falha no parsing
export PLATFORM_VERSION=13 ANDROID_MAJOR_VERSION=t SEC_BUILD_CONF_VENDOR_BUILD_OS=13

OUT="out_$MODEL"
HCF='-fcommon -Wno-error -Wno-deprecated-declarations -Wno-implicit-function-declaration'

# Passa o prefixo (-B) explícito do binutils do GCC para o Clang resolver o 'as' correto
KCF="-Wno-unknown-warning-option -fno-builtin-stpcpy -fno-builtin-strlcpy -Wno-error -Wno-strict-prototypes -Wno-old-style-definition -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types -Wno-unused-function -Wno-implicit-int -Wno-format -B$GCC_DIR/bin/aarch64-linux-android-"

COMMON="ARCH=arm64 \
O=$OUT \
CC=clang \
CROSS_COMPILE=$GCC_DIR/bin/aarch64-linux-android- \
CROSS_COMPILE_ARM32=$GCC32_DIR/bin/arm-linux-androideabi- \
CLANG_TRIPLE=aarch64-linux-gnu- \
GCC_TOOLCHAIN=$GCC_DIR \
LLVM_IAS=0"

cd "$ROOT"
echo ">> Compilando para $MODEL (Base: $BASE + ksu.config)"
echo ">> Toolchain Clang: $("$CLANG_DIR/bin/clang" --version | head -1)"
echo ">> GCC 64-bit: $("$GCC_DIR/bin/aarch64-linux-android-gcc" --version | head -1)"

# Gerar defconfig base
make $COMMON "KBUILD_HOSTCFLAGS=$HCF" "HOSTCFLAGS=$HCF" -j"$(nproc)" "$BASE"

# Mesclar configurações do KernelSU-Next + SuSFS
if [ -f arch/arm64/configs/ksu.config ]; then
    cat arch/arm64/configs/ksu.config >> "$OUT/.config"
fi

# Atualizar .config
make $COMMON "KBUILD_HOSTCFLAGS=$HCF" "HOSTCFLAGS=$HCF" -j"$(nproc)" olddefconfig

# Compilar a imagem do kernel
make $COMMON "KBUILD_HOSTCFLAGS=$HCF" "HOSTCFLAGS=$HCF" "KCFLAGS=$KCF" -j"$(nproc)" Image

IMG="$OUT/arch/arm64/boot/Image"
if [ -f "$IMG" ]; then
  echo ">> SUCESSO: $IMG ($(stat -c%s "$IMG") bytes)"
  echo ">> Imagem gerada com sucesso!"
else
  echo ">> FALHA NO BUILD"
  exit 1
fi
