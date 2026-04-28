#!/bin/bash
# fetch-kernel.sh — Download and prepare a kernel source tree for TeraStation
# Usage: fetch-kernel.sh [version]
# Default version: 6.12.77 (latest LTS recommended for Alpine V2)
set -euo pipefail

VERSION="${1:-6.12.77}"
MAJOR="${VERSION%%.*}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEST="${KERNEL_DIR:-$PROJECT_ROOT/kernel}"
TARBALL="linux-${VERSION}.tar.xz"
URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/${TARBALL}"
SIGN_URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x/${TARBALL%.xz}.sign"

echo "=== Kernel Source Fetcher ==="
echo "Version: $VERSION"
echo "URL: $URL"
echo "Destination: $DEST"
echo ""

# Check deps
for tool in curl xz tar; do
    command -v "$tool" &>/dev/null || { echo "Error: $tool not installed" >&2; exit 1; }
done

mkdir -p "$DEST"

# Download if not cached
if [ -f "$DEST/$TARBALL" ]; then
    echo "[OK] Tarball already downloaded"
else
    echo "[->] Downloading $TARBALL..."
    curl -L -# -o "$DEST/$TARBALL" "$URL" || { echo "Download failed" >&2; exit 1; }
    echo "[OK] Downloaded $(du -h "$DEST/$TARBALL" | cut -f1)"
fi

# Verify integrity (basic — check it's a valid xz archive)
if xz -t "$DEST/$TARBALL" 2>/dev/null; then
    echo "[OK] Archive integrity verified"
else
    echo "[!!] Archive appears corrupt. Delete and re-download."
    exit 1
fi

# Extract if not already done
SRCDIR="$DEST/linux-${VERSION}"
if [ -d "$SRCDIR" ]; then
    echo "[OK] Source already extracted at $SRCDIR"
else
    echo "[->] Extracting..."
    tar -xf "$DEST/$TARBALL" -C "$DEST"
    echo "[OK] Extracted to $SRCDIR"
fi

# Maintain a stable 'linux' symlink so the Makefile can find the active source tree
LINUX_LINK="$DEST/linux"
if [ -L "$LINUX_LINK" ] || [ -e "$LINUX_LINK" ]; then
    rm -f "$LINUX_LINK"
fi
ln -s "linux-${VERSION}" "$LINUX_LINK"
echo "[OK] Symlinked $LINUX_LINK -> linux-${VERSION}"

# Verify Alpine V2 support
echo ""
echo "=== Alpine V2 Support Check ==="

# Check platform config
if grep -rq 'ARCH_ALPINE' "$SRCDIR/arch/arm64/Kconfig.platforms" 2>/dev/null; then
    echo "[OK] CONFIG_ARCH_ALPINE present in Kconfig"
else
    echo "[!!] CONFIG_ARCH_ALPINE not found — this kernel may not support Alpine V2"
fi

# Check for Alpine DTS files
DTS_DIR="$SRCDIR/arch/arm64/boot/dts"
if ls "$DTS_DIR"/al/ 2>/dev/null || ls "$DTS_DIR"/amazon/ 2>/dev/null; then
    echo "[OK] Alpine device tree files found:"
    ls "$DTS_DIR"/al/*.dts "$DTS_DIR"/amazon/*.dts 2>/dev/null | while read -r f; do
        echo "      $(basename "$f")"
    done
else
    echo "[!!] No Alpine DTS directory found"
fi

# Check key drivers
echo ""
echo "=== Key Driver Status ==="
for driver in "pcie-al.c:Alpine PCIe" "ahci.c:AHCI SATA" "gpio-pl061.c:PL061 GPIO" "i2c-designware:DW I2C" "spi-dw:DW SPI"; do
    file="${driver%%:*}"
    desc="${driver##*:}"
    if find "$SRCDIR/drivers" -name "$file" 2>/dev/null | grep -q .; then
        echo "  [OK] $desc ($file)"
    else
        echo "  [!!] $desc ($file) NOT FOUND"
    fi
done

echo ""
echo "=== Next Steps ==="
echo "1. cd $SRCDIR"
echo "2. make ARCH=arm64 defconfig   (or use vendor defconfig)"
echo "3. Copy your board DTS to arch/arm64/boot/dts/al/"
echo "4. make ARCH=arm64 -j\$(nproc) Image dtbs modules"
