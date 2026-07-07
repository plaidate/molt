#!/bin/bash
# MOLT smoke runner: build instrumented, run headless in the Playdate
# Simulator, poll the datastore, report.
#
#   tools/smoke.sh [seconds] [until-grep]

set -u
SECS="${1:-300}"
UNTIL="${2:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="com.sdwfrost.molt"
DATA="$HOME/Developer/PlaydateSDK/Disk/Data/$BUNDLE"
SIM="$HOME/Developer/PlaydateSDK/bin/Playdate Simulator.app/Contents/MacOS/Playdate Simulator"

cd "$ROOT"
make smoke >/dev/null || { echo "BUILD FAILED"; exit 1; }

pkill -9 -f "Playdate Simulator" 2>/dev/null
rm -rf "$DATA" "$ROOT/build/shots"
mkdir -p "$ROOT/build/shots"
("$SIM" "$ROOT/out/MoltSmoke.pdx" >"$ROOT/build/sim.log" 2>&1 &)

ITER=$((SECS / 5))
for i in $(seq 1 "$ITER"); do
    [ -s "$DATA/err.json" ] && break
    if [ -n "$UNTIL" ] && grep -qE "$UNTIL" "$DATA/smoke.json" 2>/dev/null; then
        break
    fi
    sleep 5
done

echo "--- err:"
cat "$DATA/err.json" 2>/dev/null || echo "no error"
echo "--- smoke:"
cat "$DATA/smoke.json" 2>/dev/null || echo "NO HEARTBEAT"
echo
echo "--- save:"
cat "$DATA/save.json" 2>/dev/null || echo "no save"
echo
echo "--- shots:"
ls "$ROOT/build/shots" 2>/dev/null | tail -5

pkill -9 -f "Playdate Simulator" 2>/dev/null
mkdir -p "$ROOT/results"
cp "$DATA/smoke.json" "$ROOT/results/smoke.json" 2>/dev/null
cp "$DATA/save.json" "$ROOT/results/save.json" 2>/dev/null
rm -rf "$DATA"
