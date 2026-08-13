#!/usr/bin/env bash
set -euo pipefail

# FPGA synthesis check for the synthesizable configuration. Runs yosys over
# rv32i_soc.v (core + imem + dmem) and fails if anything does not map.
#
#   ./run_synth.sh              # Xilinx 7-series (matches the ram_style attributes)
#   TARGET=ecp5 ./run_synth.sh  # any other synth_<target> yosys provides
#
# yosys comes from the OSS CAD Suite. Either put its bin directory on PATH, or
# point YOSYSHQ_ROOT at the suite root -- on Windows the lib directory must be
# on PATH too or yosys.exe fails to load its DLLs, which is what YOSYSHQ_ROOT
# handles here.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD_DIR="$ROOT_DIR/build"
TARGET="${TARGET:-xilinx}"

if [ -n "${YOSYSHQ_ROOT:-}" ]; then
  export PATH="$YOSYSHQ_ROOT/bin:$YOSYSHQ_ROOT/lib:$PATH"
fi

YOSYS="${YOSYS:-yosys}"
if ! command -v "$YOSYS" >/dev/null 2>&1; then
  echo "yosys not found. Put the OSS CAD Suite bin directory on PATH, or set" >&2
  echo "YOSYSHQ_ROOT to the suite root, or YOSYS to the yosys binary." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"
SCRIPT="$BUILD_DIR/synth_$TARGET.ys"
LOG="$BUILD_DIR/synth_$TARGET.log"

# Both memories $readmemh("rom.hex"), so yosys has to run from the repo root.
# Paths inside the script stay relative: yosys may be a native Windows binary
# that cannot resolve the /c/... paths this shell uses.
cat > "$SCRIPT" <<EOF
read_verilog -DSYNTHESIS rv32i_soc.v rv32i_cpu.v imem.v dmem.v
synth_$TARGET -top rv32i_soc
check -assert
stat
write_json build/rv32i_soc.json
EOF

cd "$ROOT_DIR"
echo "== synthesising rv32i_soc for target '$TARGET' =="
if ! "$YOSYS" -s "$SCRIPT" > "$LOG" 2>&1; then
  echo "SYNTHESIS FAILED - see $LOG" >&2
  grep -E "^ERROR" "$LOG" >&2 || tail -n 20 "$LOG" >&2
  exit 1
fi

# Report the cell mix of the final netlist.
sed -n '/=== design hierarchy ===/,$p' "$LOG" | grep -E "^\s+[0-9]+\s+[A-Za-z]" || true

echo
echo "warnings (excluding benign block RAM port-width normalisation):"
grep -E "^Warning:" "$LOG" | grep -v "Resizing cell port" | sort -u | sed 's/^/  /' || true

echo
echo "SYNTHESIS OK - netlist written to $BUILD_DIR/rv32i_soc.json"
