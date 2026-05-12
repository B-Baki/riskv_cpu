#!/usr/bin/env python3

import sys
from pathlib import Path

def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: bin_to_hex.py input.bin output.hex")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])

    data = input_path.read_bytes()

    if len(data) % 4 != 0:
        data += bytes(4 - (len(data) % 4))

    lines = []

    for i in range(0, len(data), 4):
        word_bytes = data[i:i + 4]

        # RISC-V instructions are little-endian in memory.
        # $readmemh loads one 32-bit word per line into fiu.mem[word_index].
        word = int.from_bytes(word_bytes, byteorder="little")
        lines.append(f"{word:08x}")

    output_path.write_text("\n".join(lines) + "\n")

if __name__ == "__main__":
    main()