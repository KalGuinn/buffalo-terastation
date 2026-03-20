# Firmware Files

Buffalo TeraStation TS5020/TS3030 firmware images for reverse engineering.

These are large binaries (800MB+ each) and are **not committed to git**. Use `download.sh` to fetch and verify them, or place manually downloaded files in the project root.

## Files

| File | Version | Platform | Size |
|------|---------|----------|------|
| `ts5020_ts3030-298en.zip` | v2.98 | Windows | ~837 MB |
| `ts5020_ts3030-308en.zip` | v3.08 | Windows | ~867 MB |
| `ts5020_3030_series-298_fwmac.dmg.zip` | v2.98 | macOS | ~840 MB |
| `ts5020_3030_series-308_fwmac.dmg.zip` | v3.08 | macOS | ~870 MB |

Source: Buffalo's download servers (`download.buffalo.jp`). These are the official firmware updater packages distributed by Buffalo for the TS5020 and TS3030 NAS product lines.

## Usage

```bash
# Download and verify all firmware files (skips existing verified files)
./firmware/download.sh

# Download, verify, and extract with known passwords
./firmware/download.sh --extract

# Regenerate checksums.sha256 from files already on disk
./firmware/download.sh --checksums
```

The script is idempotent. If a file already exists and its SHA-256 matches, it is skipped.

## ZIP Passwords

The firmware ZIPs are password-protected. Buffalo uses different passwords per firmware version:

| Version | Password |
|---------|----------|
| v2.98 | `1NIf_2yUOlRDpYZUVNqboRpMBoZwT4PzoUvOPUp6l` |
| v3.08 | `aAhvlM1Yp7_2VSm6BhgkmTOrCN1JyE0C5Q6cB3oBB` |

These passwords are embedded in the Windows/macOS updater applications. They were extracted during firmware analysis.

## Directory Structure After Extraction

```
buffalo-terastation/
├── ts5020_ts3030-298en.zip              # Downloaded ZIPs (project root)
├── ts5020_ts3030-308en.zip
├── ts5020_3030_series-298_fwmac.dmg.zip
├── ts5020_3030_series-308_fwmac.dmg.zip
└── firmware/
    ├── download.sh          # This script
    ├── checksums.sha256     # SHA-256 manifest (auto-generated)
    ├── README.md            # This file
    ├── CLAUDE.md            # Claude Code context
    ├── win298/              # Extracted v2.98 Windows updater
    ├── win308/              # Extracted v3.08 Windows updater
    ├── mac298/              # Extracted v2.98 macOS updater (if --extract used)
    ├── mac308/              # Extracted v3.08 macOS updater (if --extract used)
    └── rootfs/              # Selectively extracted rootfs files
```

## Notes

- v2.98 firmware is fully extractable (all images can be decrypted and unpacked).
- v3.08 firmware has additional encryption on kernel and rootfs images; only DTBs and u-boot.img are fully recoverable.
- DTBs are identical across v2.98 and v3.08.
- The macOS `.dmg.zip` files contain the same firmware images as the Windows versions, wrapped in a different updater.
- See `notes/firmware_extraction_guide.md` for the full decryption and extraction process.
