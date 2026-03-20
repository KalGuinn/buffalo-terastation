# Buffalo TeraStation - Modern Kernel Build

## Project Overview
Reverse engineering Buffalo TeraStation NAS firmware to build a modern Linux kernel.

## Hardware Identity
- **Model:** TS51220RH9612 (TeraStation 5020 series, 12-bay rackmount)
- **SoC:** Annapurna Labs Alpine V2 (Amazon subsidiary)
- **CPU:** Quad-core ARM Cortex-A57 (ARMv8 / AArch64)
- **Architecture:** arm64 (NOT arm32 — cross-compiler is `aarch64-linux-gnu-`)
- **Original kernel:** 4.19.75 (Ubuntu 18.04 base, Buffalo-modified)
- **Target:** Modern mainline kernel (6.x)

## Key Context
- Buffalo GPL source provides inverted diffs (removals = their additions to kernel)
- Device trees successfully extracted from firmware updater ZIP (password in memory)
- DTBs are identical across firmware versions v2.98 and v3.08
- Major peripherals (SATA, Ethernet, crypto) are on internal PCIe bus, not memory-mapped
- Micon (microcontroller) on TS5020/TS51220 is USB serial via PCIe, NOT a direct UART
- The NAS is currently offline — prefer firmware RE approaches over live system methods
- Research files from Google Drive may contain errors — verify against primary sources

## Working Conventions
- Check notes/ directory for existing research before starting new analysis
- Commit to git regularly at important milestones
- Binary files go in firmware/, never in source directories
- Corrected patches go in patches/fixed/, originals stay in gpl-source/
- When unsure about hardware details, cross-reference notes/hardware_catalog.md
- Device tree ground truth: devicetree/alpine-ts51220.dts (extracted from real firmware)

## Common Tools
- `binwalk` — firmware analysis and extraction
- `dtc` — device tree compiler/decompiler (`dtc -I dtb -O dts` / `dtc -I dts -O dtb`)
- `7z` — firmware ZIP extraction (with Buffalo passwords)
- `unsquashfs` — rootfs extraction from SquashFS images
- `strings` / `hexdump` / `xxd` — binary inspection
- `openssl` — firmware decryption (AES-256-CBC with `-md md5`)
- `patch` / `diff` — source patch management
- `make` / cross-compilation toolchain — kernel builds

## Directory Structure
```
buffalo-terastation/
├── firmware/          # Original firmware files and extracted images
│   ├── win298/        # v2.98 firmware (fully extractable)
│   ├── win308/        # v3.08 firmware (DTBs extractable, kernel/rootfs encrypted)
│   └── rootfs/        # Selectively extracted rootfs files
├── gpl-source/        # Buffalo's GPL source release
│   ├── linux-4.19.75/ # Vanilla kernel source (extracted)
│   ├── *.patch        # Annapurna Labs SDK + Buffalo patches
│   └── *.txt          # Package lists
├── patches/           # Fixed (un-inverted) patches
├── devicetree/        # DTS/DTB files extracted from firmware
│   ├── alpine-ts51220.dts          # YOUR MODEL - decompiled from real DTB
│   ├── alpine-ts51220-annotated.dts # Annotated with human-readable comments
│   └── alpine-ts5020.dts          # TS5020 variant for comparison
├── research/          # Prior research files (from Google AI Studio, treat with caution)
├── kernel/            # Working kernel source tree (future)
├── tools/             # Helper scripts
└── notes/             # Research notes, analysis docs, and action plans
```

## Key Reference Documents
- `notes/ts51220_hardware_summary.md` — Complete hardware specs, I2C/GPIO/SATA maps
- `notes/kernel_build_strategy.md` — Phased plan for modern kernel
- `notes/firmware_extraction_guide.md` — How to decrypt/extract Buffalo firmware
- `notes/hardware_catalog.md` — Full peripheral catalog from defconfig analysis
- `devicetree/alpine-ts51220-annotated.dts` — Annotated device tree (ground truth)
