#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_DIR="$ROOT_DIR/tests/riscv/isa"
ROM_HEX="$ROOT_DIR/rom.hex"
SIM_OUT="$ROOT_DIR/sim.out"

# SYNTH=1 builds the synthesizable configuration: the pipelined core plus the
# registered (block RAM) imem/dmem read paths. SIM_IMEM_MIRROR keeps the
# simulation-only dmem->imem write mirror so fence_i still has something to
# test; real hardware cannot run self-modifying code.
IVFLAGS=""
if [ "${SYNTH:-0}" = "1" ]; then
  IVFLAGS="-DSYNTHESIS -DSIM_IMEM_MIRROR"
  SIM_OUT="$ROOT_DIR/sim_synth.out"
  echo "== configuration: SYNTHESIS =="
else
  echo "== configuration: behavioural =="
fi

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

iverilog -g2012 $IVFLAGS -s tb_rv32i -o "$SIM_OUT" \
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
  # ISA tests finish in <1000 cycles; cap well below the testbench default so a
  # hung test fails fast. Use run_rtos.sh for the long RTOS run.
  result=$(vvp "$SIM_OUT" +max_cycles=200000 2>&1 | grep -E "^(PASS|FAIL|TIMEOUT)" | tail -n 1)
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
