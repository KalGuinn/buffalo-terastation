# GPL Source

## CRITICAL: Inverted Diffs
Buffalo's patches use INVERTED diff format:
- Lines marked `-` (removals) are Buffalo's ADDITIONS to the kernel
- Lines marked `+` (additions) are the ORIGINAL kernel code
- To create a usable patch, swap the signs

## Files
- `linux-4.19.75/` — Vanilla kernel source (extracted from .tar.gz)
- `v4.19.75-241-g0fb91c28a25c.patch` — Annapurna Labs SDK (384 files, 9MB) — adds Alpine V2 drivers
- `linux-4.19.75_buffalo.patch` — Buffalo customizations (141 files) — NAS features, micon, defconfig
- `ts5020_gpl_installed_packages_list.txt` — Ubuntu 18.04 packages on the running NAS

## Patch Application Order
1. Start with vanilla linux-4.19.75
2. Apply Annapurna Labs SDK patch first (SoC support)
3. Apply Buffalo patch second (board/NAS features)

## Key Directories Added by Patches
- `drivers/net/ethernet/al/` — Annapurna Labs 10GbE ethernet HAL
- `buffalo/` — Buffalo platform code (micon, kernevnt, defconfig, scripts)
- `buffalo/arch/arm64/configs/buffalo_ts5020_defconfig` — The real kernel config
