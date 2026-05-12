#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <program_name_without_extension>"
  echo "Example: $0 core_basic"
  exit 1
fi

NAME="$1"

ASM="asm/${NAME}.S"
OBJ="build/${NAME}.o"
ELF="build/${NAME}.elf"
BIN="build/${NAME}.bin"
HEX="programs/${NAME}.hex"
DUMP="build/${NAME}.dump"

if [ ! -f "$ASM" ]; then
  echo "ERROR: Assembly file not found: $ASM"
  exit 1
fi

mkdir -p build programs

#-march=rv32i       target base RV32I only
#-mabi=ilp32        32-bit integer ABI
#-nostdlib          no C standard library
#-nostartfiles      no default startup code
#--no-relax         prevents linker relaxation from changing instructions unexpectedly

riscv64-unknown-elf-gcc \
  -march=rv32i \
  -mabi=ilp32 \
  -nostdlib \
  -nostartfiles \
  -ffreestanding \
  -Wl,-T,scripts/linker.ld \
  -Wl,--no-relax \
  -o "$ELF" \
  "$ASM"

riscv64-unknown-elf-objcopy -O binary "$ELF" "$BIN"

python3 scripts/bin_to_hex.py "$BIN" "$HEX"

riscv64-unknown-elf-objdump -d "$ELF" > "$DUMP"

echo "Built:"
echo "  $ELF"
echo "  $BIN"
echo "  $HEX"
echo "  $DUMP"