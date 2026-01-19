#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_DIR="$ROOT_DIR/tests/riscv/isa"
ROM_HEX="$ROOT_DIR/rom.hex"
SIM_OUT="$ROOT_DIR/sim.out"

if ! command -v iverilog >/dev/null 2>&1; then
  echo "iverilog not found in PATH" >&2
  exit 1
fi
if ! command -v vvp >/dev/null 2>&1; then
  echo "vvp not found in PATH" >&2
  exit 1
fi

mapfile -t tests < <(ls "$TEST_DIR"/rv32ui-p-*.bin.hex 2>/dev/null | sort)
if [ "${#tests[@]}" -eq 0 ]; then
  echo "No rv32ui-p-*.bin.hex tests found under $TEST_DIR" >&2
  exit 1
fi

if [ -f "$ROM_HEX" ]; then
  cp "$ROM_HEX" "$ROM_HEX.bak"
fi
trap 'if [ -f "$ROM_HEX.bak" ]; then mv -f "$ROM_HEX.bak" "$ROM_HEX"; fi' EXIT

iverilog -g2012 -s tb_rv32i -o "$SIM_OUT" \
  "$ROOT_DIR/rv32i_cpu.v" \
  "$ROOT_DIR/imem.v" \
  "$ROOT_DIR/dmem.v" \
  "$ROOT_DIR/tb_rv32i.v"

pass=0
fail=0

for t in "${tests[@]}"; do
  base=$(basename "$t" .bin.hex)
  cp "$t" "$ROM_HEX"
  echo "== $base =="
  result=$(vvp "$SIM_OUT" 2>&1 | tail -n 1)
  echo "$result"
  if echo "$result" | grep -q "PASS"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
  echo
done

echo "Total: ${#tests[@]}  PASS: $pass  FAIL: $fail"
if [ "$fail" -ne 0 ]; then
  exit 1
fi
