#!/usr/bin/env bash
# Runs one headless Godot step for CI (and locally): fails on a non-zero exit code, and also on
# any script or parse error in the output, which Godot prints without failing the run.
#
#   GODOT=/path/to/godot tools/ci/godot.sh --script res://tools/data_check.gd
#
# Each run gets its own XDG_DATA_HOME, so parallel runs never share the world save.
set -uo pipefail
GODOT="${GODOT:-godot}"
here="$(cd "$(dirname "$0")/../.." && pwd)"
data="$(mktemp -d)"
log="$(mktemp)"
XDG_DATA_HOME="$data" "$GODOT" --headless --path "$here" "$@" 2>&1 | tee "$log"
code=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load script" "$log"; then
	echo "::error::script errors in the output of: $*"
	code=1
fi
rm -rf "$data" "$log"
exit "$code"
