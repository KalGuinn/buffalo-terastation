# Buffalo TeraStation — Modern Kernel Build

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
- Buffalo GPL source provides inverted diffs — see "GPL Source" section below
- Device trees were extracted from firmware updater ZIP and are byte-identical across firmware versions v2.98 and v3.08
- Major peripherals (SATA, Ethernet, crypto) are on internal PCIe bus, not memory-mapped
- Micon (microcontroller) on TS5020/TS51220 is USB serial via PCIe, NOT a direct UART
- The NAS is currently offline — prefer firmware RE approaches over live system methods
- Research files (in `references/`) may contain errors — verify against primary sources

## Working Conventions
- Check [`notes/`](notes/) for existing research before starting new analysis (see [`notes/README.md`](notes/README.md))
- Commit to git regularly at important milestones
- Binary firmware files go in `firmware/archives/`, never tracked
- Corrected (un-inverted) patches go in `patches/`; originals stay in `gpl-source/`
- When unsure about hardware details, cross-reference `notes/hardware/hardware_catalog.md`
- Device tree ground truth: `devicetree/alpine-ts51220.dts` (decompiled from real firmware DTB)

## Wiki Sync (automatic — no manual step)

The GitHub wiki at https://github.com/KalGuinn/buffalo-terastation/wiki is **fully
generated** from this repo's docs by [`tools/build-wiki.sh`](tools/build-wiki.sh).
Never edit the wiki by hand — it is overwritten on every sync.

**Source of truth:** `README.md`, `LICENSE`, `firmware/README.md`,
`references/README.md`, `patches/README.md`, and everything under `notes/`.

**Agent responsibility:** after any commit that touches one of those paths
(check with `git diff --name-only HEAD~1 HEAD`), invoke the
[`update-wiki`](.claude/skills/update-wiki/SKILL.md) skill — which runs the
generator and pushes — without prompting the user. Likewise before merging a
branch into `main` if the branch touched any wiki source. This is meant to be
transparent infrastructure; the user should not have to remember to run it.

If only `gpl-source/`, `devicetree/`, `kernel/`, `firmware/` binaries, `tools/`,
`.claude/`, `CLAUDE.md`, or `Makefile` changed, skip the sync — none of those
are mapped to wiki pages.

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
├── README.md                    # Project writeup
├── CLAUDE.md                    # This file (Claude Code context)
├── LICENSE                      # MIT
├── Makefile                     # Kernel build targets
├── .gitignore
├── .devcontainer/               # Dev container setup
├── firmware/                    # Firmware acquisition + extracted images
│   ├── README.md                # How to obtain and extract firmware
│   ├── download.sh              # Reproducible download + verify + extract
│   ├── checksums.sha256
│   ├── archives/                # (gitignored) downloaded ZIPs
│   ├── win298/, win308/         # (gitignored) extracted Windows updaters
│   └── rootfs/                  # (gitignored) selectively extracted rootfs files
├── gpl-source/                  # Buffalo's GPL release
│   ├── linux-4.19.75/           # (gitignored) extracted vanilla kernel
│   ├── *.patch                  # Annapurna Labs SDK + Buffalo patches
│   └── ts5020_gpl_installed_packages_list.txt
├── patches/                     # Reserved for un-inverted Buffalo patches
├── devicetree/                  # DTS/DTB extracted from firmware
│   ├── alpine-ts51220.dts             # YOUR MODEL — decompiled from real DTB
│   ├── alpine-ts51220-annotated.dts   # Annotated with human-readable comments
│   ├── alpine-ts5020.dts              # TS5020 variant for comparison
│   └── *.dtb                          # Binary DTBs from firmware
├── references/                  # Primary-source raw artifacts
│   ├── README.md
│   ├── datasheets/              # Buffalo product datasheets
│   ├── kernel-snippets/         # defconfig, out-of-tree driver patches
│   └── firmware-snippets/       # micon driver source, uImage layout
├── kernel/                      # (gitignored) working kernel source tree
├── tools/                       # Helper scripts
└── notes/                       # Research notes, organized by topic
    ├── README.md                # Index
    ├── hardware/                # Hardware specs, catalog, DTS gaps
    ├── firmware/                # Extraction guide, rootfs analysis
    ├── kernel/                  # Build strategy, version tracking
    ├── community_research.md
    └── project_status_and_next_steps.md
```

## Firmware

Large binary files — do NOT commit to git (covered by `.gitignore`).

### Structure (in `firmware/`)
- `archives/` — downloaded ZIPs (gitignored)
- `win298/` — v2.98 Windows firmware updater (fully extractable)
- `win308/` — v3.08 Windows firmware updater (DTBs extractable, kernel/rootfs encrypted)
- `mac298/`, `mac308/` — macOS firmware updaters (same images, different wrappers)
- `rootfs/` — selectively extracted files from the v2.98 SquashFS rootfs

### Reproducing
`./firmware/download.sh --extract` — fetches all 4 archives, verifies SHA-256, and extracts using embedded passwords. See `firmware/README.md` for direct URLs and manual fetch.

### ZIP Passwords
- v2.98: `1NIf_2yUOlRDpYZUVNqboRpMBoZwT4PzoUvOPUp6l`
- v3.08: `aAhvlM1Yp7_2VSm6BhgkmTOrCN1JyE0C5Q6cB3oBB` (only u-boot.img fully decrypts; kernel/rootfs have additional encryption)

## GPL Source

Buffalo's GPL source release lives in `gpl-source/`:
- `linux-4.19.75/` — vanilla kernel source (extracted from `.tar.gz`, gitignored)
- `v4.19.75-241-g0fb91c28a25c.patch` — Annapurna Labs SDK (384 files, 9MB) — adds Alpine V2 drivers
- `linux-4.19.75_buffalo.patch` — Buffalo customizations (141 files) — NAS features, micon, defconfig
- `ts5020_gpl_installed_packages_list.txt` — Ubuntu 18.04 packages on the running NAS

### CRITICAL: Inverted Diffs
Buffalo's patches use **INVERTED** diff format:
- Lines marked `-` (removals) are Buffalo's **ADDITIONS** to the kernel
- Lines marked `+` (additions) are the **ORIGINAL** kernel code
- To create a usable patch, swap the signs

### Patch Application Order
1. Start with vanilla `linux-4.19.75`
2. Apply Annapurna Labs SDK patch first (SoC support)
3. Apply Buffalo patch second (board/NAS features)

### Key Directories Added by Patches
- `drivers/net/ethernet/al/` — Annapurna Labs 10GbE ethernet HAL
- `buffalo/` — Buffalo platform code (micon, kernevnt, defconfig, scripts)
- `buffalo/arch/arm64/configs/buffalo_ts5020_defconfig` — the real kernel config

## Device Tree

### Ground Truth
The `.dtb` files in `devicetree/` were extracted directly from Buffalo firmware v2.98 and are byte-identical to v3.08. The `.dts` files were decompiled from those DTBs using `dtc -I dtb -O dts`.

### Files
- `alpine-ts51220.dtb` / `.dts` — TS51220RH9612 (the target hardware, 12-bay rackmount)
- `alpine-ts5020.dtb` / `.dts` — Standard TS5020 (8-bay desktop)
- `alpine-ts3030.dtb` / `.dts` — TS3030 variant
- `alpine-ts3030r.dtb` / `.dts` — TS3030R variant
- `alpine-ts51220-annotated.dts` — fully annotated version with decoded hex values

### Validation
Always validate DTS changes: `dtc -I dts -O dtb -o /dev/null <file>.dts`

### Key Differences: TS51220 vs TS5020
- TS51220 has PCA9548 I2C mux; TS5020 does not
- TS51220 bays 5–12 use PCIe-attached SAS HBAs; TS5020 uses native SATA for all bays
- Different SerDes tuning parameters
- Micon on both is USB serial via PCIe (not direct UART like TS3030)

## Notes Index
See [`notes/README.md`](notes/README.md). Topical layout: `hardware/`, `firmware/`, `kernel/`, plus `community_research.md` and `project_status_and_next_steps.md` at the top level.

## Communication Style
Be direct. Skip filler phrases and performed enthusiasm. State facts, not reactions.
