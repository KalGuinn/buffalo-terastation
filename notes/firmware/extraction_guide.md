# Buffalo TeraStation TS5020 - Firmware Extraction & DTB Recovery Guide

## Table of Contents
1. [Overview](#overview)
2. [Tools Required](#tools-required)
3. [Firmware File Structure](#firmware-file-structure)
4. [Known Buffalo Encryption Keys](#known-buffalo-encryption-keys)
5. [Method 1: Decrypt Firmware Images with OpenSSL](#method-1-decrypt-firmware-images-with-openssl)
6. [Method 2: Extract from Firmware Updater EXE](#method-2-extract-from-firmware-updater-exe)
7. [Method 3: Extract DTB from U-Boot FIT Image](#method-3-extract-dtb-from-u-boot-fit-image)
8. [Method 4: Dump DTB from a Running System](#method-4-dump-dtb-from-a-running-system)
9. [Method 5: Reconstruct DTB from GPL Source](#method-5-reconstruct-dtb-from-gpl-source)
10. [Method 6: Using acp_commander for SSH Access](#method-6-using-acp_commander-for-ssh-access)
11. [TS5020-Specific Notes](#ts5020-specific-notes)
12. [Troubleshooting](#troubleshooting)
13. [References](#references)

---

## Overview

Buffalo NAS devices (LinkStation, TeraStation) ship with encrypted firmware update
images. The DTB (Device Tree Blob) needed to boot a custom kernel is typically
embedded in the firmware -- either inside the kernel image (appended DTB), inside
a U-Boot FIT image, or stored on a separate boot partition.

The TS5020 series uses:
- **SoC:** Annapurna Labs Alpine V2 (Amazon/AWS acquisition)
- **Architecture:** ARM64 (AArch64), Cortex-A57 quad-core
- **Compatible strings:** `al,alpine-v2-evp`, `al,alpine-v2`
- **Base DTS:** `alpine-v2-evp.dts` (from GPL source debianize.sh)
- **Kernel:** Linux 4.19.75 (Buffalo-modified)

The challenge: Buffalo did NOT include their board-specific DTS in the GPL release.
The build system references `buffalo/arch/arm64/boot/dts/` as `EXTRA_DTSDIR` but
this directory is empty in the released source. The actual board DTS must be
extracted from the firmware.

---

## Tools Required

Install these tools on macOS or Linux:

```bash
# macOS (Homebrew)
brew install binwalk dtc openssl p7zip squashfs

# Debian/Ubuntu
sudo apt install binwalk device-tree-compiler openssl p7zip-full squashfs-tools u-boot-tools
```

Specific tools and their purposes:
- **binwalk** -- firmware analysis, finds embedded filesystems and images
- **dtc** -- device tree compiler/decompiler (DTB <-> DTS conversion)
- **fdtdump** -- dumps FDT (Flattened Device Tree) in human-readable form
- **openssl** -- AES decryption of Buffalo firmware images
- **7z / p7zip** -- extract files from Windows .exe firmware updaters
- **unsquashfs** -- extract SquashFS root filesystems
- **mkimage / dumpimage** -- U-Boot image manipulation (from u-boot-tools)
- **strings / hexdump** -- binary inspection

---

## Firmware File Structure

Buffalo firmware updates typically contain these components:

```
firmware_update.exe          # Windows self-extracting updater
  |
  +-- TSUpdater.ini          # Update configuration / version info
  +-- initrd.buffalo         # Encrypted ramdisk (update initrd)
  +-- hddrootfs.buffalo.encrypted  # Encrypted root filesystem image
  +-- uImage.buffalo         # Encrypted kernel + DTB image
  +-- u-boot.buffalo         # Encrypted bootloader image (sometimes)
  +-- linkstation_version.txt
```

Some products use slightly different naming:
- `initrd.img` / `initrd.buffalo`
- `hddrootfs.img` / `hddrootfs.buffalo.encrypted`
- `uImage` / `uImage.buffalo`

The `.buffalo` extension typically indicates the file is AES-encrypted.
Some files use a custom header before the encrypted payload.

### Buffalo Firmware Header Format

Buffalo firmware files often have a custom header structure:
```
Offset  Size  Description
0x00    4     Magic / signature bytes
0x04    4     Header length or flags
0x08    4     Data length (payload size)
0x0C    4     Checksum or padding
0x10+   var   Encrypted payload (AES-256-CBC)
```

The header must be stripped before decryption. The header size varies by product
generation -- common sizes are 0 bytes (no header), 8 bytes, or a larger
structured header.

---

## Known Buffalo Encryption Keys

Buffalo has historically used AES encryption with static keys embedded in their
firmware update tools. Community research has documented several keys:

### Commonly Documented Keys

| Key / Password | Products | Algorithm | Notes |
|---------------|----------|-----------|-------|
| `buffaloinc` | Older LinkStation/TeraStation | AES-128-CBC | Widely documented |
| `1NIf_2yUOlRDpYZUVNqboRpMJOxfE38c` | LS200, LS400, LS500 series | AES-256-CBC | Found in update scripts |
| `YvSInIQopeipx66t-fNPmMQhHfCK3MRe` | Some TeraStation models | AES-256-CBC | From update tools |
| `IeY8omJwGlGkIbJm2FH_MV4fLsieI3Lo` | Various | AES-256-CBC | From acp_commander |
| `bufbufbufbufbufb` | Older models | AES-128-CBC | Simplified key |
| `a]S7}6qRm,UEYjHt` | LS-WXL series | AES-128-CBC | |

### Key Discovery Methods

Keys are typically found in:
1. **The firmware updater itself** -- embedded in the Windows .exe or in update scripts
2. **initrd scripts** -- the update ramdisk contains shell scripts with decryption commands
3. **acp_commander output** -- the Java-based NAS administration tool sometimes reveals keys
4. **U-Boot environment** -- stored in the bootloader's environment variables
5. **Update shell scripts** -- `/usr/local/sbin/` on running systems

### How to Extract Keys from the Firmware Updater

```bash
# Extract the .exe with 7z
7z x firmware_updater.exe -ofirmware_extracted/

# Search for encryption keys in extracted files
strings -n 8 firmware_extracted/* | grep -iE 'aes|key|pass|encrypt|decrypt|openssl'

# Look in any shell scripts
find firmware_extracted/ -name "*.sh" -exec grep -l 'openssl\|aes\|encrypt' {} \;

# Search for openssl command patterns
strings firmware_extracted/* | grep 'openssl enc'
```

---

## Method 1: Decrypt Firmware Images with OpenSSL

This is the primary method for older Buffalo firmware (pre-secure-boot).

### Step 1: Extract files from firmware updater

```bash
mkdir -p firmware/extracted
cd firmware/

# If the firmware is a Windows .exe:
7z x TS5020_firmware_v298.exe -oextracted/

# List what was extracted
ls -la extracted/
```

### Step 2: Identify encrypted files

```bash
# Check file types
file extracted/*

# Look for encrypted Buffalo files
ls extracted/*.buffalo* extracted/*.encrypted* 2>/dev/null

# Examine headers with hexdump
hexdump -C extracted/initrd.buffalo | head -5
hexdump -C extracted/uImage.buffalo | head -5
```

### Step 3: Attempt decryption with known keys

Try each known key until one works. A successful decryption will produce
recognizable output (gzip magic bytes `1f 8b`, or U-Boot header `27 05 19 56`).

```bash
# Try AES-256-CBC with various keys (no header stripping)
for key in \
    "buffaloinc" \
    "1NIf_2yUOlRDpYZUVNqboRpMJOxfE38c" \
    "YvSInIQopeipx66t-fNPmMQhHfCK3MRe" \
    "IeY8omJwGlGkIbJm2FH_MV4fLsieI3Lo" \
    "a]S7}6qRm,UEYjHt"
do
    echo "=== Trying key: $key ==="
    openssl enc -d -aes-256-cbc \
        -in extracted/initrd.buffalo \
        -out initrd_test.img \
        -k "$key" \
        -md md5 \
        2>/dev/null && \
    file initrd_test.img && \
    hexdump -C initrd_test.img | head -3
    echo ""
done
```

### Step 4: Handle different OpenSSL versions

OpenSSL 1.1+ changed the default digest for key derivation from MD5 to SHA256.
Buffalo firmware was encrypted with older OpenSSL, so you must specify `-md md5`:

```bash
# OpenSSL 1.x style (MD5 key derivation) -- try this first
openssl enc -d -aes-256-cbc -k "THE_KEY" -md md5 -in encrypted_file -out decrypted_file

# If that fails, try SHA256 (newer OpenSSL)
openssl enc -d -aes-256-cbc -k "THE_KEY" -md sha256 -in encrypted_file -out decrypted_file

# Also try AES-128-CBC for older products
openssl enc -d -aes-128-cbc -k "THE_KEY" -md md5 -in encrypted_file -out decrypted_file
```

### Step 5: Handle Buffalo header stripping

Some firmware files have a header that must be removed before decryption:

```bash
# Skip first N bytes (try 0, 8, 16, 64, 128)
dd if=extracted/uImage.buffalo bs=1 skip=8 of=uImage.buffalo.stripped
openssl enc -d -aes-256-cbc -k "THE_KEY" -md md5 -in uImage.buffalo.stripped -out uImage.decrypted

# Check if decrypted output looks valid
file uImage.decrypted
hexdump -C uImage.decrypted | head -5
```

### Step 6: Verify and extract decrypted images

```bash
# If the decrypted file is a gzip archive:
gunzip -k initrd_decrypted.img.gz
# or
zcat initrd_decrypted.img.gz > initrd_decrypted.img

# If it's a cpio archive (initrd):
mkdir initrd_contents
cd initrd_contents
cpio -idmv < ../initrd_decrypted.img

# If it's a U-Boot image:
mkimage -l uImage.decrypted    # list image info
dumpimage -i uImage.decrypted -p 0 kernel.bin   # extract kernel
```

---

## Method 2: Extract from Firmware Updater EXE

The Windows .exe firmware updater can be dissected to find the embedded images.

### Step 1: Extract with 7z

```bash
7z x TS5020_firmware.exe -ofirmware_contents/
ls -la firmware_contents/
```

### Step 2: If 7z doesn't work, try binwalk

```bash
binwalk -e TS5020_firmware.exe
ls _TS5020_firmware.exe.extracted/
```

### Step 3: Analyze with binwalk for embedded content

```bash
# Scan for known file signatures
binwalk TS5020_firmware.exe

# Look specifically for:
# - U-Boot headers (magic: 27 05 19 56)
# - gzip compressed data (magic: 1f 8b)
# - SquashFS filesystems
# - Device tree blobs (magic: d0 0d fe ed)
# - Linux kernel images
```

### Step 4: Search for DTB magic bytes

```bash
# Search for FDT magic (0xd00dfeed) in any extracted file
xxd firmware_contents/* 2>/dev/null | grep 'd00dfeed'

# Or use binwalk's DTB signature scanning
binwalk -R '\xd0\x0d\xfe\xed' firmware_contents/*
```

---

## Method 3: Extract DTB from U-Boot FIT Image

If you've found a U-Boot image (FIT or legacy), the DTB may be embedded within it.

### Understanding FIT Images

FIT (Flattened Image Tree) is U-Boot's modern image format. It packages kernel,
DTB, and initrd into a single file using the FDT (device tree) format itself.

### Step 1: Identify the image type

```bash
# Check for U-Boot image header (magic: 27 05 19 56)
hexdump -C uImage | head -1
# Expected: 00000000  27 05 19 56 ...

# For FIT images, the magic is the FDT magic (d0 0d fe ed)
# FIT images are device tree blobs containing other images

mkimage -l uImage    # List image contents
```

### Step 2: Extract from legacy uImage

```bash
# Extract the payload (strips U-Boot header)
dd if=uImage bs=64 skip=1 of=payload.bin

# Check what the payload is
file payload.bin
binwalk payload.bin
```

### Step 3: Extract from FIT image

```bash
# List FIT image contents
dumpimage -l fit_image.itb

# Extract individual components
dumpimage -i fit_image.itb -p 0 -o kernel.bin    # kernel (position 0)
dumpimage -i fit_image.itb -p 1 -o dtb.bin       # DTB (position 1)
dumpimage -i fit_image.itb -p 2 -o initrd.bin    # initrd (position 2)

# Or use fdtdump to inspect the FIT structure
fdtdump fit_image.itb
```

### Step 4: Scan for DTB within any binary

The DTB magic bytes are `0xd00dfeed`. You can scan any binary for embedded DTBs:

```bash
# Find all DTB offsets in a file
python3 -c "
import struct, sys
data = open(sys.argv[1], 'rb').read()
magic = b'\\xd0\\x0d\\xfe\\xed'
offset = 0
while True:
    pos = data.find(magic, offset)
    if pos == -1:
        break
    # Read the totalsize field (big-endian uint32 at offset 4)
    size = struct.unpack('>I', data[pos+4:pos+8])[0]
    print(f'DTB found at offset 0x{pos:x}, size {size} bytes')
    offset = pos + 1
" uImage

# Extract each found DTB
dd if=uImage bs=1 skip=OFFSET count=SIZE of=extracted.dtb

# Decompile to DTS
dtc -I dtb -O dts -o extracted.dts extracted.dtb
```

### Step 5: Use binwalk for automated extraction

```bash
# binwalk knows the DTB/FDT magic
binwalk -e uImage

# Look for .dtb files in the extracted directory
find _uImage.extracted/ -name "*.dtb" -o -name "*.dts"

# Or manually scan
binwalk uImage | grep -i "device tree\|flattened"
```

### Dealing with Encrypted U-Boot Images

If the U-Boot image or its embedded DTB appears encrypted (no recognizable
structures, high entropy throughout):

```bash
# Check entropy to confirm encryption
binwalk -E uImage

# A fully encrypted file will show uniformly high entropy (~1.0)
# A file with an unencrypted header + encrypted body will show a drop then high entropy

# Try the Buffalo decryption keys first (see Method 1)
# Then try extracting after decryption
```

---

## Method 4: Dump DTB from a Running System

**This is the most reliable method if you have SSH or console access to the NAS.**

### Option A: Copy the live device tree

The Linux kernel exposes the active device tree through several interfaces:

```bash
# Method 1: Binary FDT blob (best -- exact copy of what the kernel uses)
# Available on kernels 3.19+
cp /sys/firmware/fdt ./ts5020.dtb
dtc -I dtb -O dts -o ts5020.dts ./ts5020.dtb

# Method 2: Device tree filesystem (alternative)
# This is a directory tree, not a single blob
ls /sys/firmware/devicetree/base/
# or
ls /proc/device-tree/

# Method 3: Read model and compatible strings to verify
cat /sys/firmware/devicetree/base/model
cat /sys/firmware/devicetree/base/compatible
```

### Option B: Read from boot partition

```bash
# Find the boot partition
lsblk
fdisk -l /dev/sda

# Mount the boot partition
mount /dev/sda1 /mnt/boot    # adjust partition as needed

# Look for DTB files
find /mnt/boot -name "*.dtb" -o -name "*.dtb.*"
ls /mnt/boot/dtbs/
ls /mnt/boot/boot/

# The DTB might be appended to the kernel image
# or stored in a FIT image
file /mnt/boot/uImage
```

### Option C: Extract from /proc/config.gz

Even if you can't get the DTB directly, the running kernel config is valuable:

```bash
# Get the running kernel config
zcat /proc/config.gz > running_config

# Check device tree related configs
grep -i "CONFIG_ARCH_ALPINE\|CONFIG_DTB\|CONFIG_OF" running_config
```

### Option D: Read kernel boot log for DT info

```bash
# The boot log contains device tree information
dmesg | grep -i "machine\|model\|device.tree\|OF:\|fdt\|dtb"

# Look for the model string
dmesg | head -30
```

---

## Method 5: Reconstruct DTB from GPL Source

Since the TS5020 GPL source contains the base `alpine-v2-evp.dts` and the
`alpine-v2.dtsi`, you can attempt to reconstruct a working DTB.

### What We Know from the GPL Source

From `gpl-source/linux-4.19.75/arch/arm64/boot/dts/al/`:
- `alpine-v2.dtsi` -- SoC-level definition (CPUs, GIC, UARTs, timers, PCIe, MSI)
- `alpine-v2-evp.dts` -- Evaluation Platform board file (minimal)

From `buffalo/scripts/debianize.sh` (in the patch):
- `DTSNAMES="alpine-v2-evp.dts"` -- the TS5020 builds this DTS
- `EXTRA_DTSDIR="buffalo/arch/arm64/boot/dts/"` -- Buffalo overrides go here
- The build script copies files from EXTRA_DTSDIR into the kernel DTS directory

### What's Missing (Not in GPL Release)

Buffalo's board-specific DTS modifications likely include:
- SATA controller configuration (AHCI via PCIe)
- I2C bus definitions (for temperature sensors, EEPROM)
- GPIO definitions (LEDs, buttons, fan control)
- UART1 assignment for micon (microcontroller) communication at 115200 baud
  (see `micon_v3.c` which uses `/dev/ttyS1`)
- Network interface (Ethernet) configuration
- USB host controller configuration
- RTC (real-time clock) on I2C
- SPI flash for boot storage

### Reconstruction Approach

```bash
# 1. Start with the EVP DTS as a base
cp gpl-source/linux-4.19.75/arch/arm64/boot/dts/al/alpine-v2-evp.dts \
   devicetree/ts5020-reconstructed.dts

# 2. Enable additional hardware nodes based on defconfig analysis
#    The defconfig tells us what drivers are enabled, which implies
#    what hardware needs DT nodes.

# 3. Compile to verify syntax
dtc -I dts -O dtb -o devicetree/ts5020-reconstructed.dtb \
    devicetree/ts5020-reconstructed.dts

# 4. Key modifications needed (see TS5020-Specific Notes below)
```

### Key Defconfig Clues for DTS Reconstruction

From the `buffalo_ts5020_defconfig` analysis:
- `CONFIG_ARCH_ALPINE=y` -- Alpine platform
- `CONFIG_SERIAL_8250=y` -- NS16550 UARTs (4 defined in dtsi)
- `CONFIG_I2C=y` -- I2C bus controller
- `CONFIG_HWMON=y` -- Hardware monitoring (temperature sensors)
- `CONFIG_SATA_AHCI=y` -- AHCI SATA (via PCIe)
- `CONFIG_USB_XHCI_HCD=y` -- USB 3.0
- `CONFIG_EXT4_FS=y`, `CONFIG_XFS_FS=y` -- Filesystem support
- `CONFIG_BUFFALO_MICON_V3=y` -- Microcontroller on ttyS1
- `CONFIG_NET_VENDOR_REALTEK=y`, R8125 driver -- 2.5GbE Realtek NIC

---

## Method 6: Using acp_commander for SSH Access

`acp_commander` is a Java tool that exploits the Buffalo ACP (Admin Control
Protocol) to gain root access on Buffalo NAS devices.

### Install and Use acp_commander

```bash
# Download acp_commander.jar (search GitHub for "acp_commander")
# Requires Java runtime

# Discover the NAS on the network
java -jar acp_commander.jar -f

# Enable SSH/telnet (may require the admin password)
java -jar acp_commander.jar -t <NAS_IP> -ip <NAS_IP> -pw <ADMIN_PASSWORD> -c "sed -i 's/nossh/ssh/' /etc/nas_features"

# Or directly spawn a root shell via ACP
java -jar acp_commander.jar -t <NAS_IP> -ip <NAS_IP> -pw <ADMIN_PASSWORD> -c "/usr/sbin/sshd"

# Alternative: enable telnet
java -jar acp_commander.jar -t <NAS_IP> -ip <NAS_IP> -pw <ADMIN_PASSWORD> -c "inetd"
```

### Once SSH is Available

```bash
ssh root@<NAS_IP>

# Dump the device tree
cp /sys/firmware/fdt /tmp/ts5020.dtb
dtc -I dtb -O dts /tmp/ts5020.dtb > /tmp/ts5020.dts

# Or if dtc isn't installed on the NAS:
cat /sys/firmware/fdt > /tmp/ts5020.dtb
# Then scp it off:
scp root@<NAS_IP>:/tmp/ts5020.dtb ./

# Also grab useful system info while you're in:
cat /proc/cpuinfo
cat /proc/device-tree/model
dmesg > /tmp/dmesg.log
cat /proc/config.gz > /tmp/config.gz   # if available
lspci -v
cat /proc/mtd                          # flash partitions
fw_printenv                            # U-Boot environment variables
```

---

## TS5020-Specific Notes

### Architecture

The TS5020 is **ARM64 (AArch64)**, not ARM32. This is important because:
- Earlier TeraStation models (TS5010, TS3010) used ARM32 Alpine V1
- The TS5020 uses Alpine V2 with Cortex-A57 cores
- Cross-compiler must be `aarch64-linux-gnu-` not `arm-linux-gnueabihf-`

### Firmware Version Differences

- **v2.98**: Reported to be easier to extract; may use older/weaker encryption
- **v3.08+**: Improved encryption, possibly related to secure boot additions
  - May use signed firmware images
  - May have moved away from simple AES-CBC with static keys
  - If secure boot is enforced, even a decrypted image won't boot without signing

### Microcontroller (Micon)

The TS5020 has a microcontroller ("micon") connected via UART (ttyS1 at 115200
baud) that controls:
- Power button / power state
- LEDs
- Buzzer / beeper
- Reboot commands

This must be accounted for in the device tree (uart1 must be enabled and
accessible as `/dev/ttyS1`).

### Network Interface

The TS5020 uses a **Realtek RTL8125** 2.5GbE NIC (PCIe). The Buffalo GPL source
includes a separate patch for the R8125 driver (`linux-4.19.75_r8125-9.012.04.patch`).
This is a PCIe device so it may not need a DT node beyond the PCIe controller
definition already in the dtsi.

### What the EVP DTS Provides vs What's Needed

The stock `alpine-v2-evp.dts` only enables:
- uart0 (serial console at 115200)

A working TS5020 DTS additionally needs (at minimum):
- uart1 enabled (for micon)
- Memory node (size depends on model: 4GB or 8GB)
- I2C controllers
- Additional PCIe configuration if needed
- GPIO controllers for LEDs/buttons

---

## Troubleshooting

### "bad decrypt" from OpenSSL
- Wrong key, wrong algorithm (try AES-128 vs AES-256), or wrong digest (-md md5 vs -md sha256)
- File may have a header that needs stripping (try `dd bs=1 skip=N`)
- File may use a different encryption scheme entirely (not OpenSSL-compatible)

### binwalk finds nothing in the firmware
- File may be fully encrypted (check entropy with `binwalk -E`)
- Try decrypting first, then running binwalk on the decrypted output

### DTB decompilation fails
- May not be a real DTB -- verify magic bytes `d0 0d fe ed` at the start
- May be truncated -- check the size field at offset 4
- May be encrypted or obfuscated even within the image

### No /sys/firmware/fdt on running system
- Kernel must be compiled with `CONFIG_OF=y` and `CONFIG_PROC_DEVICETREE=y`
- Try `/proc/device-tree/` instead
- On very old kernels, the device tree may not be exported to userspace

### Encrypted DTB in U-Boot image
- U-Boot may decrypt the DTB at boot time using a key stored in SPI flash
- Check U-Boot environment: `fw_printenv` for any key/crypto variables
- Check U-Boot source for product-specific decryption routines
- The TS5020's v3.08 firmware may use Annapurna Labs secure boot which
  encrypts/signs all boot stage images including the DTB

### v3.08 firmware won't decrypt
- v3.08 likely uses secure boot with per-device or model-specific keys
  burned into eFuses or stored in OTP (One-Time Programmable) memory
- Fallback: use v2.98 firmware which has weaker protection
- Fallback: dump DTB from a running system instead of from firmware files

---

## References

### Community Resources
- BuffaloNAS Wiki - Extract Boot Files: https://buffalonas.miraheze.org/wiki/Extract_Boot_Files_from_Stock_Firmware
- NT Lab Blog - Opening LinkStation firmware: https://blog.ntlab.id/2014/11/11/opening-stock-firmware-of-linkstation-ls421de/
- linkstation-mod tools: https://github.com/tohenk/linkstation-mod
- Marcus Folkesson - Take control of Buffalo LinkStation: https://www.marcusfolkesson.se/blog/take-control-of-your-buffalo-linkstation/
- Aaron Hastings - Recovering bricked LinkStation: https://blog.aaronhastings.me/completely-recovering-from-a-bricked-buffalo-linkstation-ls200-series-nas-and-opening-the-firmware-too/
- OpenLinkstation project: https://github.com/rogers0/OpenLinkstation

### Technical References
- Annapurna Labs Alpine V2 in mainline Linux: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/arch/arm64/boot/dts/al
- U-Boot FIT image documentation: https://u-boot.readthedocs.io/en/latest/usage/fit/index.html
- Device Tree specification: https://www.devicetree.org/specifications/

### Tools
- acp_commander: search GitHub for "acp_commander buffalo"
- binwalk: https://github.com/ReFirmLabs/binwalk
- dtc (device tree compiler): https://git.kernel.org/pub/scm/utils/dtc/dtc.git

---

## Recommended Attack Plan

Given the current project state (DTB in U-Boot image appears encrypted), the
recommended order of approach is:

1. **Try SSH/acp_commander first** (Method 6 + Method 4) -- if the NAS is running
   and on the network, dumping `/sys/firmware/fdt` gives you the exact DTB with
   zero guesswork. This is by far the easiest path.

2. **Try decrypting v2.98 firmware** (Method 1) -- older firmware is more likely
   to use known static keys. Try all documented keys with both AES-128 and
   AES-256, with and without header stripping.

3. **Scan extracted files for DTB magic** (Method 3) -- even partially decrypted
   or extracted files might contain embedded DTBs at known offsets.

4. **Reconstruct from GPL source** (Method 5) -- use the EVP DTS as a base and
   add nodes based on defconfig analysis and hardware inspection. This is a
   last resort but viable since the Alpine V2 SoC is well-documented in mainline
   Linux and the EVP board file is a reasonable starting point.

5. **Search for keys in the .exe** (Method 2) -- strings analysis on the firmware
   updater executable may reveal encryption keys or other useful metadata.
