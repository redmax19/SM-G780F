#!/bin/bash
# ============================================================================
#  KernelSU-Next + SuSFS v2.0.0 — Galaxy S20 FE 4G (Exynos 990 / SM-G780F)
#
#  Device:    Galaxy S20 FE 4G (SM-G780F / r8slte)
#  Config:    arch/arm64/configs/exynos9830-r8slte_defconfig + ksu.config
#  Toolchain: Clang 8 JOPP + GCC 4.9 JOPP (localizados em ../tc/clang10 e ../tc/gcc49)
# ============================================================================
set -e

MODEL="g780f"
BASE="exynos9830-r8slte_defconfig"

ROOT="$(cd "$(dirname "$0")" && pwd)"
CLANG_DIR="${CLANG_DIR:-$ROOT/../tc/clang10}"
GCC_DIR="${GCC_DIR:-$ROOT/../tc/gcc49}"

[ -x "$CLANG_DIR/bin/clang" ] || { echo "ERROR: clang não encontrado em $CLANG_DIR — defina CLANG_DIR"; exit 1; }

export PATH="$CLANG_DIR/bin:$GCC_DIR/bin:$PATH"
export ARCH=arm64 LC_ALL=C

# Samsung Kconfig macros exigidas para evitar falha no parsing do defconfig
export PLATFORM_VERSION=13 ANDROID_MAJOR_VERSION=t SEC_BUILD_CONF_VENDOR_BUILD_OS=13

OUT="out_$MODEL"
HCF='-fcommon -Wno-error -Wno-deprecated-declarations -Wno-implicit-function-declaration'
KCF='-Wno-unknown-warning-option -fno-builtin-stpcpy -fno-builtin-strlcpy -Wno-error -Wno-strict-prototypes -Wno-old-style-definition -Wno-implicit-function-declaration -Wno-int-conversion -Wno-incompatible-pointer-types -Wno-unused-function -Wno-implicit-int -Wno-format'

# CROSS_COMPILE com caminho completo e LLVM_IAS=0 para evitar o erro do bin/as (-EL)
COMMON="ARCH=arm64 O=$OUT CC=clang CROSS_COMPILE=$GCC_DIR/bin/aarch64-linux-android- CLANG_TRIPLE=aarch64-linux-gnu- LLVM_IAS=0"

cd "$ROOT"
echo ">> Compilando para $MODEL (Base: $BASE + ksu.config)"
echo ">> Toolchain Clang: $("$CLANG_DIR/bin/clang" --version | head -1)"

# Gerar defconfig base
make $COMMON "KBUILD_HOSTCFLAGS=$HCF" "HOSTCFLAGS=$HCF" -j"$(nproc)" "$BASE"

# Mesclar configurações do KernelSU-Next + SuSFS
cat arch/arm64/configs/ksu.config >> "$OUT/.config"

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
