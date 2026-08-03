#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
RTOS_DIR="$ROOT_DIR/rtos"
RTOS_HEX="$RTOS_DIR/rtos.hex"
ROM_HEX="$ROOT_DIR/rom.hex"
SIM_OUT="$ROOT_DIR/sim_rtos.out"

# A full test_rtos.c run needs ~330k cycles behaviourally and ~430k in the
# SYNTHESIS configuration (loads cost an extra cycle there); leave headroom.
MAX_CYCLES="${MAX_CYCLES:-2000000}"

# SYNTH=1 builds the synthesizable configuration; see run_riscv_tests.sh.
IVFLAGS=""
if [ "${SYNTH:-0}" = "1" ]; then
  IVFLAGS="-DSYNTHESIS -DSIM_IMEM_MIRROR"
  SIM_OUT="$ROOT_DIR/sim_rtos_synth.out"
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

# Rebuild the RTOS image when a riscv toolchain is available, otherwise fall
# back to the rtos.hex checked into the tree.
if [ "${REBUILD:-0}" = "1" ]; then
  echo "== building rtos =="
  make -C "$RTOS_DIR" clean
  make -C "$RTOS_DIR"
fi

if [ ! -f "$RTOS_HEX" ]; then
  echo "$RTOS_HEX not found (run 'make -C rtos' first)" >&2
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

cp "$RTOS_HEX" "$ROM_HEX"

echo "== rtos =="
result=$(vvp "$SIM_OUT" "+max_cycles=$MAX_CYCLES" 2>&1 | grep -E "^(PASS|FAIL|TIMEOUT)" | tail -n 1)
echo "$result"

if echo "$result" | grep -q "^PASS"; then
  exit 0
fi
exit 1
