# Project Roadmap

_Last reviewed: 2026-04-27_

Status of the TeraStation TS51220 modern-kernel-build effort. Reader-facing —
for "what's been figured out, what's in flight, and what's next."

For internal session notes and tooling/harness work, see the parent `~/Claude/`
workspace; this page is scoped to the kernel-build project only.

---

## Done

**Hardware identification.** SoC confirmed as Annapurna Labs Alpine V2 (ARM Cortex-A57, AArch64). Earlier ARM32 assumptions corrected. Full hardware specs in [`hardware/ts51220_hardware_summary.md`](hardware/ts51220_hardware_summary.md).

**Firmware extraction pipeline.** Reproducible end-to-end: ZIP password recovery, AES-256-CBC decryption keys, SHA-256 verification. Both v2.98 (fully extractable) and v3.08 (DTBs and `u-boot.img` only) are scripted via [`firmware/download.sh`](../firmware/download.sh). Procedure documented in [`firmware/extraction_guide.md`](firmware/extraction_guide.md).

**Device tree recovery.** DTBs extracted from firmware updater ZIP. Confirmed byte-identical between v2.98 and v3.08. Decompiled to DTS, then human-annotated against rootfs evidence. The TS51220 device tree is now ground truth: [`devicetree/alpine-ts51220-annotated.dts`](../devicetree/alpine-ts51220-annotated.dts).

**Hardware catalog.** Every driver from Buffalo's defconfig classified (upstream / needs-porting / droppable) with register addresses and bus topology. See [`hardware/hardware_catalog.md`](hardware/hardware_catalog.md).

**Rootfs analysis.** Selectively extracted from the v2.98 SquashFS. Boot config (`config-4.19.75-*` — Buffalo's actual production .config), Buffalo init scripts, udev rules, and the micon (microcontroller) binaries. Full micon command set extracted by static analysis: [`firmware/rootfs_analysis.md`](firmware/rootfs_analysis.md).

**Phased build strategy.** Plan documented for vendor 4.19.75 → modern 6.x with risk assessment per subsystem: [`kernel/build_strategy.md`](kernel/build_strategy.md).

**Community/prior-art survey.** QNAP Alpine V2 work, mainline upstream status, what AWS Nitro upstreaming gives us "for free": [`community_research.md`](community_research.md).

**Public release.** Repo cleaned up and published to https://github.com/KalGuinn/buffalo-terastation on 2026-04-27.

## In progress

**Patch un-inversion.** Buffalo's GPL diffs use inverted format (their additions appear as `-` lines). Need to produce usable forward patches before any kernel work. AL SDK patch (~384 files) and Buffalo patch (~141 files) are both still raw in [`gpl-source/`](../gpl-source/); [`patches/`](../patches/) is the destination for corrected output and is currently empty.

**Boot config analysis.** Buffalo's running `config-4.19.75-*` (160 KB) is the most authoritative reference for "what hardware needs support." Has been extracted but not yet diffed against the hardware catalog to find anything missed.

## Planned

### Phase 1 — finish research before touching kernel source

- Cross-check Buffalo's running `.config` against the hardware catalog; close any gaps.
- Verify the recommended LTS target (currently 6.12) per [`kernel/kernel_version_selection.md`](kernel/kernel_version_selection.md), specifically:
  - Alpine V2 DTSI completeness in `arch/arm64/boot/dts/amazon/`
  - Status of `pcie-al`, `alpine-msi`, `al-fic` in current sources
  - AL Ethernet driver presence in `drivers/net/ethernet/amazon/`
- Diff mainline `alpine-v2.dtsi` against the extracted DTS to determine how much board-specific DTS work is needed.
- U-Boot investigation: boot sequence (`booti` vs. `bootm`), signed-kernel enforcement, accessible env. Extract from firmware images; the U-Boot binary lives in SPI flash partition 0 (3 MB).
- Categorize the two GPL patches: which files are out-of-tree drivers worth keeping (al_eth, AL HAL, thermal), which are Buffalo NAS userspace plumbing that can be dropped.

### Phase 2 — minimal boot kernel

- Download target kernel source (6.12 LTS or whichever Phase 1 verifies).
- Set up cross-compilation (Docker or devcontainer; toolchain `aarch64-linux-gnu-`).
- Minimal defconfig: `ARCH_ALPINE` + serial + PCIe + AHCI.
- Adapt DTS for mainline: start from upstream `alpine-v2.dtsi`, layer on the board-specific nodes from the extracted TS51220 DTS.
- Build `Image` + `dtb`. Test boot via TFTP + UART console (requires physical access).

### Phase 3 — full hardware support

- Ethernet: either an off-the-shelf Intel PCIe NIC (fast path, requires a free slot) or port the AL ethernet driver (multi-week effort, native 10 GbE).
- I2C peripherals: should "just work" once the DTS is correct.
- AL Thermal driver: port the out-of-tree driver, or replace with a generic thermal binding.
- Micon userspace daemon: fan/LED/LCD/button control. Protocol is documented; implementation is fresh code.
- EDAC, NAND, DMA acceleration — nice-to-have, last.

---

## Open questions before serious build work starts

1. **Physical access** — is the TS51220 reachable for serial console + TFTP boot? Determines whether Phase 2 can run end-to-end.
2. **PCIe slot for an Intel NIC** — single biggest risk reducer. Skipping the AL eth port saves weeks.
3. **U-Boot signing** — if the bootloader enforces signed kernels, Phase 2 needs a different boot path (custom U-Boot or a key recovery).
4. **AL SDK patch scope** — un-invert the whole 384-file patch, or selectively extract only the drivers we need? Selective is faster but risks missing dependencies.
