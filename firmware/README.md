# Firmware

Buffalo TeraStation TS5020 / TS3030 firmware updater archives, plus extracted images.

The archives total ~3.4 GB and are **gitignored**. Use [`download.sh`](download.sh) to fetch and verify them, or download manually using the links below.

## Archives

| File | Version | Platform | Approx. size |
|---|---|---|---|
| `ts5020_ts3030-298en.zip` | v2.98 | Windows | ~837 MB |
| `ts5020_ts3030-308en.zip` | v3.08 | Windows | ~867 MB |
| `ts5020_3030_series-298_fwmac.dmg.zip` | v2.98 | macOS | ~840 MB |
| `ts5020_3030_series-308_fwmac.dmg.zip` | v3.08 | macOS | ~870 MB |

The Windows and macOS variants contain the same firmware images wrapped in different updater applications.

## Automated fetch (recommended)

```sh
./firmware/download.sh              # download + verify SHA-256 only
./firmware/download.sh --extract    # download + verify + extract password-protected ZIPs
./firmware/download.sh --checksums  # regenerate checksums.sha256 from local files
```

Idempotent — files that already exist with correct SHA-256 are skipped. Archives land in `firmware/archives/`. The script extracts to `firmware/win298/`, `firmware/win308/`, etc.

## Manual fetch (fallback)

If Buffalo's CDN URLs change, fetch directly from one of:

- **Buffalo Japan CDN (canonical):** <https://download.buffalo.jp/driver/NAS/TeraStation/> — current source used by `download.sh`. Append the filename from the table above to the URL.
- **Buffalo Americas support:** <https://www.buffalo-technology.com/support/downloads/> — browsable, may host newer firmware.

Place the downloaded archives in `firmware/archives/` and run:

```sh
sha256sum -c firmware/checksums.sha256   # or `shasum -a 256 -c` on macOS
./firmware/download.sh --extract         # will skip downloads, just extract
```

## ZIP passwords

The firmware ZIPs are password-protected. The passwords are embedded in Buffalo's publicly distributed updater applications (extractable with `strings` on the Windows `.exe` or by reading the macOS `.dmg`'s setup scripts) and are reproduced here so the extraction is replicable:

| Version | Password |
|---|---|
| v2.98 | `1NIf_2yUOlRDpYZUVNqboRpMBoZwT4PzoUvOPUp6l` |
| v3.08 | `aAhvlM1Yp7_2VSm6BhgkmTOrCN1JyE0C5Q6cB3oBB` |

For additional historical Buffalo firmware keys (other product lines, older AES-128 schemes), see [`../notes/firmware/extraction_guide.md`](../notes/firmware/extraction_guide.md).

## Extraction layout

After `download.sh --extract`:

```
firmware/
├── archives/                          # downloaded ZIPs (gitignored)
│   ├── ts5020_ts3030-298en.zip
│   ├── ts5020_ts3030-308en.zip
│   ├── ts5020_3030_series-298_fwmac.dmg.zip
│   └── ts5020_3030_series-308_fwmac.dmg.zip
├── win298/                            # gitignored
├── win308/                            # gitignored
├── mac298/, mac308/                   # gitignored, only with --extract
└── rootfs/                            # gitignored, populated separately
```

## What you get

- **v2.98 firmware:** fully extractable. Kernel image, rootfs (SquashFS), DTBs, u-boot all decrypt with the published Buffalo AES-256-CBC key (`md5` digest mode). See [`../notes/firmware/extraction_guide.md`](../notes/firmware/extraction_guide.md) for the openssl command.
- **v3.08 firmware:** partial. Only `u-boot.img` and the DTBs decrypt with the same key. The kernel image (`uImage`) and rootfs have an additional encryption layer not yet broken.
- **DTBs are byte-identical across v2.98 and v3.08** — this is how the device tree was recovered without needing to break the v3.08 kernel/rootfs encryption.

See [`../notes/firmware/rootfs_analysis.md`](../notes/firmware/rootfs_analysis.md) for what's been pulled out of the rootfs (init scripts, micon driver, kernel modules).
