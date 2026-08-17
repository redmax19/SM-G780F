#!/bin/bash
set -e

MODEL="g780f"
while getopts "m:" o; do case $o in m) MODEL=$OPTARG ;; esac; done
case "$MODEL" in
  g985f) BASE=exynos9830-y2slte_defconfig ;;
  g780f) BASE=exynos9830-r8slte_defconfig ;;
  g988b) BASE=exynos9830-z3sxxx_defconfig ;;
  g986b) BASE=exynos9830-y2sxxx_defconfig ;;
  g981b) BASE=exynos9830-x1sxxx_defconfig ;;
  *)   echo "Unknown model '$MODEL'"; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")" && pwd)"
CLANG_DIR="$(realpath "${CLANG_DIR:-$ROOT/../tc/clang10}")"
GCC_DIR="$(realpath "${GCC_DIR:-$ROOT/../tc/gcc49}")"
GCC32_DIR="$(realpath "${GCC32_DIR:-$ROOT/../tc/gcc32}")"

export PATH="$CLANG_DIR/bin:$GCC_DIR/bin:$GCC32_DIR/bin:$PATH"
export ARCH=arm64 LC_ALL=C
export PLATFORM_VERSION=13 ANDROID_MAJOR_VERSION=t SEC_BUILD_CONF_VENDOR_BUILD_OS=13

OUT="out_$MODEL"
HCF='-fcommon -Wno-error -Wno-deprecated-declarations -Wno-implicit-function-declaration'
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
echo ">> Compilando para $MODEL (Base: $BASE)"

make $COMMON "KBUILD_HOSTCFLAGS=$HCF" "HOSTCFLAGS=$HCF" -j"$(nproc)" "$BASE"

if [ -f arch/arm64/configs/ksu.config ]; then
    cat arch/arm64/configs/ksu.config >> "$OUT/.config"
fi

# Desativa drivers de teste debug da Samsung que quebram o relinking final no AArch64
sed -i 's/CONFIG_EXYNOS_DEBUG_TEST=y/# CONFIG_EXYNOS_DEBUG_TEST is not set/' "$OUT/.config"
sed -i 's/CONFIG_SEC_DEBUG_TEST=y/# CONFIG_SEC_DEBUG_TEST is not set/' "$OUT/.config"

make $COMMON "KBUILD_HOSTCFLAGS=$HCF" "HOSTCFLAGS=$HCF" -j"$(nproc)" olddefconfig
make $COMMON "KBUILD_HOSTCFLAGS=$HCF" "HOSTCFLAGS=$HCF" "KCFLAGS=$KCF" -j"$(nproc)" Image

IMG="$OUT/arch/arm64/boot/Image"
if [ -f "$IMG" ]; then
  echo ">> SUCESSO: $IMG ($(stat -c%s "$IMG") bytes)"
else
  echo ">> FALHA NO BUILD"
  exit 1
fi
