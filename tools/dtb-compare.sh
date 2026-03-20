#!/bin/bash
# dtb-compare.sh — Compare two DTB files by decompiling and diffing
# Usage: dtb-compare.sh <dtb1> <dtb2>
set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <dtb1> <dtb2>"
    echo "Decompiles both DTBs and shows a structured diff."
    exit 1
fi

DTB1="$1"
DTB2="$2"

for f in "$DTB1" "$DTB2"; do
    [ -f "$f" ] || { echo "Error: $f not found" >&2; exit 1; }
done

command -v dtc &>/dev/null || { echo "Error: dtc not installed (brew install dtc)" >&2; exit 1; }

TMP1=$(mktemp /tmp/dtb-cmp1-XXXXXX)
TMP2=$(mktemp /tmp/dtb-cmp2-XXXXXX)
trap "rm -f $TMP1 $TMP2" EXIT

dtc -I dtb -O dts -s "$DTB1" > "$TMP1" 2>/dev/null
dtc -I dtb -O dts -s "$DTB2" > "$TMP2" 2>/dev/null

echo "=== DTB Comparison ==="
echo "A: $DTB1 ($(du -h "$DTB1" | cut -f1))"
echo "B: $DTB2 ($(du -h "$DTB2" | cut -f1))"
echo ""

DIFF_COUNT=$(diff "$TMP1" "$TMP2" | grep -c '^[<>]' 2>/dev/null || true)

if [ "$DIFF_COUNT" -eq 0 ]; then
    echo "Files are identical when decompiled."
else
    echo "$DIFF_COUNT differing lines."
    echo ""
    if command -v delta &>/dev/null; then
        delta "$TMP1" "$TMP2" || true
    else
        diff -u --label "$DTB1" --label "$DTB2" "$TMP1" "$TMP2" || true
    fi
fi
