#!/bin/bash
# fw-analyze.sh — Quick firmware image analysis toolkit
# Usage: fw-analyze.sh <image_file> [command]
# Commands: info, entropy, strings, hexdump, binwalk, dtb, all
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <image_file> [info|entropy|strings|hexdump|binwalk|dtb|all]"
    echo ""
    echo "Commands:"
    echo "  info      File type, size, magic bytes (default)"
    echo "  entropy   Binwalk entropy analysis"
    echo "  strings   Extract interesting strings (IPs, URLs, versions, configs)"
    echo "  hexdump   First 512 bytes with hexyl"
    echo "  binwalk   Full binwalk scan"
    echo "  dtb       Attempt DTB decompilation"
    echo "  all       Run all analyses"
    exit 1
fi

FILE="$1"
CMD="${2:-info}"

if [ ! -f "$FILE" ]; then
    echo "Error: $FILE not found" >&2
    exit 1
fi

info() {
    echo "=== File Info ==="
    echo "Path: $(realpath "$FILE")"
    echo "Size: $(du -h "$FILE" | cut -f1)"
    file "$FILE"
    echo ""
    echo "SHA256: $(shasum -a 256 "$FILE" | cut -d' ' -f1)"
    echo ""
    echo "=== Magic Bytes (first 16) ==="
    xxd -l 16 "$FILE"
    echo ""
    # Check for known headers
    MAGIC=$(xxd -p -l 4 "$FILE")
    case "$MAGIC" in
        27051956) echo ">> uImage header detected" ;;
        d00dfeed) echo ">> Device Tree Blob (DTB) detected" ;;
        7f454c46) echo ">> ELF binary detected" ;;
        1f8b*)    echo ">> gzip compressed data" ;;
        fd377a58) echo ">> xz compressed data" ;;
        504b0304) echo ">> ZIP archive" ;;
        68737173) echo ">> SquashFS filesystem" ;;
        30373037) echo ">> CPIO archive" ;;
        *)        echo ">> Unknown format: $MAGIC" ;;
    esac
}

entropy_scan() {
    echo "=== Entropy Analysis ==="
    if command -v binwalk &>/dev/null; then
        binwalk -E "$FILE" 2>/dev/null | head -30
    else
        echo "binwalk not installed"
    fi
}

interesting_strings() {
    echo "=== Interesting Strings ==="
    echo "--- IP addresses ---"
    strings "$FILE" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u | head -20
    echo ""
    echo "--- URLs ---"
    strings "$FILE" | grep -oE 'https?://[^ ]+' | sort -u | head -20
    echo ""
    echo "--- Version strings ---"
    strings "$FILE" | grep -iE '(version|v[0-9]+\.[0-9]+|linux|kernel|buffalo|terastation|alpine)' | sort -u | head -30
    echo ""
    echo "--- Config paths ---"
    strings "$FILE" | grep -E '^/(etc|usr|var|sys|proc|dev)/' | sort -u | head -30
    echo ""
    echo "--- Crypto/key references ---"
    strings "$FILE" | grep -iE '(password|key|secret|aes|encrypt|decrypt|openssl|cipher)' | sort -u | head -20
}

hex_header() {
    echo "=== Hex Dump (first 512 bytes) ==="
    if command -v hexyl &>/dev/null; then
        hexyl -n 512 "$FILE"
    else
        xxd -l 512 "$FILE"
    fi
}

binwalk_scan() {
    echo "=== Binwalk Scan ==="
    if command -v binwalk &>/dev/null; then
        binwalk "$FILE"
    else
        echo "binwalk not installed"
    fi
}

dtb_decompile() {
    echo "=== DTB Decompilation Attempt ==="
    if command -v dtc &>/dev/null; then
        if dtc -I dtb -O dts "$FILE" 2>/dev/null | head -50; then
            echo "... (truncated, use dtc -I dtb -O dts $FILE for full output)"
        else
            echo "Not a valid DTB file"
        fi
    else
        echo "dtc not installed"
    fi
}

case "$CMD" in
    info)     info ;;
    entropy)  entropy_scan ;;
    strings)  interesting_strings ;;
    hexdump)  hex_header ;;
    binwalk)  binwalk_scan ;;
    dtb)      dtb_decompile ;;
    all)
        info
        echo ""
        hex_header
        echo ""
        binwalk_scan
        echo ""
        interesting_strings
        echo ""
        entropy_scan
        ;;
    *)
        echo "Unknown command: $CMD" >&2
        exit 1
        ;;
esac
