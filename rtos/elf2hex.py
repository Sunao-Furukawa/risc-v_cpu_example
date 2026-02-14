#!/usr/bin/env python3
import sys

def main():
    if len(sys.argv) != 3:
        print("usage: elf2hex.py <input.bin> <output.hex>")
        return 1
    in_path, out_path = sys.argv[1], sys.argv[2]
    with open(in_path, "rb") as f:
        data = f.read()
    if len(data) % 4 != 0:
        data += b"\x00" * (4 - (len(data) % 4))
    lines = []
    for i in range(0, len(data), 4):
        b0 = data[i]
        b1 = data[i + 1]
        b2 = data[i + 2]
        b3 = data[i + 3]
        word = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
        lines.append(f"{word:08x}")
    with open(out_path, "w", newline="\n") as f:
        f.write("\n".join(lines))
        if lines:
            f.write("\n")
    return 0

if __name__ == "__main__":
    sys.exit(main())
