#!/usr/bin/env bash
#
# download.sh — Download and verify Buffalo TeraStation TS5020/TS3030 firmware
#
# Idempotent: skips files that already exist with correct checksums.
# Optionally extracts password-protected ZIPs after download.
#
# Usage:
#   ./download.sh              # download and verify only
#   ./download.sh --extract    # download, verify, and extract
#   ./download.sh --checksums  # regenerate checksums.sha256 from existing files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOAD_DIR="$SCRIPT_DIR/archives"
MANIFEST="$SCRIPT_DIR/checksums.sha256"

mkdir -p "$DOWNLOAD_DIR"

# --------------------------------------------------------------------------
# Firmware definitions
# --------------------------------------------------------------------------
# Format: filename|sha256|description|extract_password|extract_subdir
#
# Windows firmware updaters (EXE-based, contain firmware images inside)
# macOS firmware updaters (DMG-based, same firmware images, different wrapper)
#
# Buffalo's download servers have historically been at:
#   https://download.buffalo.jp/driver/NAS/TeraStation/
# Direct links may change; if downloads fail, check Buffalo's support site.
# --------------------------------------------------------------------------

FIRMWARE_ENTRIES=(
  "ts5020_ts3030-298en.zip|5ecb523a8ae3c8c78ad311d244c06dc69940d4585c90b8eace539d9f20b8e169|TS5020/TS3030 v2.98 Windows firmware updater|1NIf_2yUOlRDpYZUVNqboRpMBoZwT4PzoUvOPUp6l|win298"
  "ts5020_ts3030-308en.zip|e9c69391531992aa0b63df4659be0293d43b7f064a8ef1b97b06ce9ea4191008|TS5020/TS3030 v3.08 Windows firmware updater|aAhvlM1Yp7_2VSm6BhgkmTOrCN1JyE0C5Q6cB3oBB|win308"
  "ts5020_3030_series-298_fwmac.dmg.zip|196747f7662f9e7016c1f674312dbabb66449208208c38403b52ff8a3243bf7e|TS5020/TS3030 v2.98 macOS firmware updater|1NIf_2yUOlRDpYZUVNqboRpMBoZwT4PzoUvOPUp6l|mac298"
  "ts5020_3030_series-308_fwmac.dmg.zip|0b0d8ae46e9bf407ffe9ed1251ee17fc242b7e235ff7827ceb5d2032688ef1d8|TS5020/TS3030 v3.08 macOS firmware updater|aAhvlM1Yp7_2VSm6BhgkmTOrCN1JyE0C5Q6cB3oBB|mac308"
)

# Base URL for Buffalo's download server.
# Direct links may change; if downloads fail, check Buffalo's support site.
DOWNLOAD_BASE="https://download.buffalo.jp/driver/NAS/TeraStation"

get_download_url() {
    printf '%s/%s' "$DOWNLOAD_BASE" "$1"
}

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${BOLD}[INFO]${RESET}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${RESET}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${RESET}  %s\n" "$*"; }

sha256_check() {
    local file="$1" expected="$2"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    local actual
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]]
}

# --------------------------------------------------------------------------
# Actions
# --------------------------------------------------------------------------

do_download() {
    local filename="$1" expected_sha="$2" description="$3"
    local filepath="$DOWNLOAD_DIR/$filename"

    info "Processing: $description"

    # Check if already downloaded and valid
    if sha256_check "$filepath" "$expected_sha"; then
        ok "$filename — already present, checksum verified"
        return 0
    fi

    if [[ -f "$filepath" ]]; then
        warn "$filename — exists but checksum mismatch, re-downloading"
    fi

    # Attempt download
    local url
    url="$(get_download_url "$filename")"

    info "Downloading $filename from $url"
    if curl -fSL --progress-bar -o "$filepath.part" "$url"; then
        mv "$filepath.part" "$filepath"
    else
        rm -f "$filepath.part"
        fail "$filename — download failed (HTTP error or network issue)"
        warn "You may need to download manually from Buffalo's support site:"
        warn "  https://www.buffalo-technology.com/support/downloads/"
        return 1
    fi

    # Verify after download
    if sha256_check "$filepath" "$expected_sha"; then
        ok "$filename — downloaded and verified"
    else
        fail "$filename — checksum mismatch after download!"
        fail "Expected: $expected_sha"
        fail "Got:      $(shasum -a 256 "$filepath" | awk '{print $1}')"
        return 1
    fi
}

do_extract() {
    local filename="$1" password="$2" subdir="$3"
    local filepath="$DOWNLOAD_DIR/$filename"
    local extract_dir="$SCRIPT_DIR/$subdir"

    if [[ ! -f "$filepath" ]]; then
        warn "$filename — not found, skipping extraction"
        return 1
    fi

    if [[ -d "$extract_dir" ]] && [[ "$(ls -A "$extract_dir" 2>/dev/null)" ]]; then
        ok "$filename — already extracted to $subdir/"
        return 0
    fi

    mkdir -p "$extract_dir"
    info "Extracting $filename to firmware/$subdir/"

    local rc=0
    if command -v 7z &>/dev/null; then
        7z x -p"$password" -o"$extract_dir" "$filepath" -y >/dev/null 2>&1 || rc=$?
    elif command -v unzip &>/dev/null; then
        unzip -P "$password" -o "$filepath" -d "$extract_dir" >/dev/null 2>&1 || rc=$?
    else
        fail "No extraction tool found (need 7z or unzip)"
        return 1
    fi

    if [[ $rc -eq 0 ]]; then
        ok "$filename — extracted to firmware/$subdir/"
    else
        fail "$filename — extraction failed (wrong password or corrupt archive?)"
        return 1
    fi
}

generate_manifest() {
    info "Generating checksums manifest: $MANIFEST"
    : > "$MANIFEST"
    local count=0
    for entry in "${FIRMWARE_ENTRIES[@]}"; do
        IFS='|' read -r filename expected_sha description _password _subdir <<< "$entry"
        local filepath="$DOWNLOAD_DIR/$filename"
        if [[ -f "$filepath" ]]; then
            printf '%s  %s\n' "$expected_sha" "$filename" >> "$MANIFEST"
            count=$((count + 1))
        fi
    done
    ok "Wrote $count entries to checksums.sha256"
}

# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

MODE="download"
if [[ "${1:-}" == "--extract" ]]; then
    MODE="extract"
elif [[ "${1:-}" == "--checksums" ]]; then
    MODE="checksums"
elif [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    printf "Usage: %s [--extract|--checksums|--help]\n\n" "$(basename "$0")"
    printf "  (no args)     Download and verify firmware files\n"
    printf "  --extract     Download, verify, and extract with known passwords\n"
    printf "  --checksums   Regenerate checksums.sha256 from files on disk\n"
    printf "  --help        Show this help\n"
    exit 0
fi

printf "\n${BOLD}Buffalo TeraStation TS5020/TS3030 Firmware Manager${RESET}\n"
printf "Download dir: %s\n\n" "$DOWNLOAD_DIR"

errors=0

for entry in "${FIRMWARE_ENTRIES[@]}"; do
    IFS='|' read -r filename expected_sha description password subdir <<< "$entry"

    if ! do_download "$filename" "$expected_sha" "$description"; then
        errors=$((errors + 1))
        continue
    fi

    if [[ "$MODE" == "extract" ]]; then
        if ! do_extract "$filename" "$password" "$subdir"; then
            errors=$((errors + 1))
        fi
    fi
done

printf "\n"

# Always regenerate manifest after download/verify pass
generate_manifest

printf "\n"
if [[ $errors -eq 0 ]]; then
    ok "All firmware files OK"
else
    fail "$errors file(s) had errors"
    exit 1
fi
