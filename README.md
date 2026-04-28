# Buffalo TeraStation TS51220 — Firmware RE & Modern Kernel Build

Reverse engineering a Buffalo TeraStation TS51220RH9612 NAS (Annapurna Labs Alpine V2, ARM64) toward a modern mainline Linux kernel.

**Status:** active research / WIP. Firmware extraction and device-tree recovery are complete; mainline kernel port is in progress. Last meaningful update: 2026-04.

---

## What this project demonstrates

- **Firmware reverse engineering** on a closed embedded ARM64 platform with no upstream support and a partially-encrypted firmware pipeline.
- **AES-256-CBC firmware image decryption** using keys recovered from the vendor's distributed updater binaries — see [`notes/firmware/extraction_guide.md`](notes/firmware/extraction_guide.md).
- **Password extraction** from proprietary Windows / macOS updater executables (the firmware ZIP passwords are embedded in the updater apps — they are reproduced here so the work is replicable).
- **Device tree recovery** from raw DTBs (Buffalo did not release DTS): `dtc -I dtb -O dts` on extracted blobs, then human-annotated DTS reconstruction matched against rootfs evidence — see [`devicetree/alpine-ts51220-annotated.dts`](devicetree/alpine-ts51220-annotated.dts).
- **Linux kernel patch analysis** on Buffalo's GPL release, which ships diffs in **inverted format** (their additions appear as `-` lines). See [`CLAUDE.md`](CLAUDE.md#gpl-source) for the inversion convention and patch application order.
- **Rootfs static analysis** (SquashFS) — extracted the full **micon** (microcontroller) command set used to drive fan/LED/power on the chassis. See [`notes/firmware/rootfs_analysis.md`](notes/firmware/rootfs_analysis.md).
- **Phased mainlining strategy** — vendor 4.19.75 → modern 6.x — documented in [`notes/kernel/build_strategy.md`](notes/kernel/build_strategy.md).

---

## Hardware target

| Field | Value |
|---|---|
| Model | Buffalo TeraStation TS51220RH9612 (TS5020 series, 12-bay rackmount) |
| SoC | Annapurna Labs Alpine V2 (Amazon subsidiary) |
| CPU | Quad-core ARM Cortex-A57 (ARMv8 / AArch64) |
| Architecture | arm64 |
| Vendor kernel | 4.19.75 (Ubuntu 18.04 base, Buffalo-modified) |
| Target kernel | Mainline 6.x |

Why this is non-trivial:

- **Alpine V2 mainline support is thin.** Annapurna Labs upstreamed parts of the platform for AWS Nitro, but the NAS-relevant SoC bring-up (PCIe controllers, board-specific peripherals) lives in vendor patches, not upstream.
- **Peripherals are on internal PCIe**, not memory-mapped — SATA, Ethernet, crypto are all PCIe-attached. The DTS reflects this; many drivers need PCIe quirks, not platform_device bindings.
- **Firmware is partially encrypted.** v2.98 is fully extractable. v3.08 has additional AES-256-CBC encryption on kernel and rootfs images (only DTBs and `u-boot.img` decrypt with the published keys). The DTBs are byte-identical across versions, which is how this project's ground-truth device tree was recovered.

---

## Methodology

- **Primary-source verification.** The decompiled DTBs in [`devicetree/`](devicetree/) are the ground truth. Vendor docs and cached "research" notes (in [`references/`](references/)) are cross-checked against them, not the other way around.
- **Reproducible extraction pipeline.** [`firmware/download.sh`](firmware/download.sh) fetches the firmware archives, verifies SHA-256, and extracts with the recovered passwords — anyone can rerun the work end to end.
- **Patches over rebases.** Buffalo's GPL drop is preserved verbatim in [`gpl-source/`](gpl-source/); corrected (un-inverted) patches go in [`patches/`](patches/) once produced. The vanilla kernel and the working tree (`kernel/`) are gitignored — fetched on demand by [`tools/fetch-kernel.sh`](tools/fetch-kernel.sh).

---

## Repository layout

```
buffalo-terastation/
├── README.md                # this file
├── CLAUDE.md                # working conventions / Claude Code context
├── LICENSE                  # MIT (original work); GPL'd kernel patches retain GPL v2
├── Makefile                 # kernel build targets (defconfig, dtbs, kernel, modules, uimage)
├── firmware/                # firmware acquisition + extracted images
│   ├── README.md            # canonical "how to obtain & extract firmware"
│   ├── download.sh          # reproducible fetch + SHA-256 verify + extract
│   ├── checksums.sha256
│   └── archives/            # gitignored — downloaded ZIPs (~3.4 GB)
├── gpl-source/              # Buffalo's GPL release: vendor patches + package list
├── patches/                 # un-inverted patches (work product)
├── devicetree/              # DTBs extracted from firmware + decompiled DTS
│   └── alpine-ts51220-annotated.dts   # ground-truth annotated DTS
├── kernel/                  # gitignored — working kernel source tree (fetch-kernel.sh)
├── tools/                   # helper scripts (firmware analysis, DTB diff, kernel fetch)
├── references/              # primary-source raw artifacts (datasheets, snippets)
└── notes/                   # research notes, organized by topic
    ├── hardware/  firmware/  kernel/
    ├── community_research.md
    └── project_status_and_next_steps.md
```

---

## Key artifacts (drill-in)

- [`devicetree/alpine-ts51220-annotated.dts`](devicetree/alpine-ts51220-annotated.dts) — Annotated ground-truth device tree for the target hardware
- [`notes/firmware/extraction_guide.md`](notes/firmware/extraction_guide.md) — Full firmware decryption / extraction procedure with recovered keys
- [`notes/hardware/ts51220_hardware_summary.md`](notes/hardware/ts51220_hardware_summary.md) — Peripheral catalog, I2C / GPIO / SATA maps
- [`notes/hardware/hardware_catalog.md`](notes/hardware/hardware_catalog.md) — Defconfig-derived peripheral catalog
- [`notes/firmware/rootfs_analysis.md`](notes/firmware/rootfs_analysis.md) — SquashFS rootfs analysis + micon protocol
- [`notes/kernel/build_strategy.md`](notes/kernel/build_strategy.md) — Phased mainline plan (4.19.75 → 6.x)
- [`notes/community_research.md`](notes/community_research.md) — Prior-art survey (QNAP Alpine V2 work, etc.)
- [`firmware/download.sh`](firmware/download.sh) — Reproducible fetch + verify + extract

---

## Reproducing the work

### Get the firmware

The firmware archives (~3.4 GB total) are gitignored. To fetch them:

```sh
./firmware/download.sh --extract
```

This downloads all four archives from Buffalo's CDN, verifies SHA-256, and extracts the password-protected ZIPs. See [`firmware/README.md`](firmware/README.md) for the full procedure, manual download links if Buffalo's CDN URLs go stale, and direct links to:

- Buffalo Japan CDN (canonical): <https://download.buffalo.jp/driver/NAS/TeraStation/>
- Buffalo Americas support: <https://www.buffalo-technology.com/support/downloads/>

The SHA-256 manifest at [`firmware/checksums.sha256`](firmware/checksums.sha256) lets you verify any archive obtained out-of-band.

### Analyze

```sh
./tools/fw-analyze.sh firmware/archives/ts5020_ts3030-298en.zip   # binwalk + image fingerprinting
./tools/dtb-compare.sh devicetree/alpine-ts51220.dtb devicetree/alpine-ts5020.dtb
```

### Build a kernel

```sh
./tools/fetch-kernel.sh 6.12.77    # downloads + extracts + creates kernel/linux symlink
make defconfig                     # placeholder; vendor defconfig port still in progress
make kernel dtbs modules
```

---

## Status

**Done:**
- Firmware acquisition + decryption pipeline working (v2.98 fully; v3.08 DTBs + u-boot only)
- DTBs extracted, decompiled, annotated; TS51220 / TS5020 / TS3030 / TS3030R variants compared
- Hardware catalog complete (every peripheral from the vendor defconfig mapped to a driver)
- Micon (chassis MCU) protocol extracted from rootfs — full command set documented
- Annapurna Labs SDK + Buffalo patches inventoried; "inverted diff" convention identified

**Next:**
- Un-invert vendor patches into a clean `patches/` series
- Build vanilla 4.19.75 with the extracted DTS as a baseline
- Forward-port Alpine V2 platform support and board-specific drivers to mainline 6.x
- Bring up the device with the new kernel via netconsole / serial recovery

See [`notes/project_status_and_next_steps.md`](notes/project_status_and_next_steps.md) for detail.

---

## Acknowledgements & legal

- Buffalo Inc. for releasing the GPL kernel source.
- The BuffaloNAS / acp_commander community for prior firmware RE work — the historical AES key list in [`notes/firmware/extraction_guide.md`](notes/firmware/extraction_guide.md) is community-documented (BuffaloNAS wiki, acp_commander source).
- The TS5020 / TS3030 firmware ZIP passwords reproduced here are extracted from Buffalo's publicly distributed Windows / macOS updater applications. They are included so the extraction is reproducible without re-deriving them; they are not novel disclosures.

This repository contains:
- Original analysis, notes, scripts, and tooling — **MIT licensed** (see [`LICENSE`](LICENSE)).
- Buffalo GPL kernel source patches under `gpl-source/` — these remain under **GPL v2** per Buffalo's release.
- Buffalo's TS5020 datasheet under `references/datasheets/` — included for reference under fair use; copyright Buffalo Inc.
