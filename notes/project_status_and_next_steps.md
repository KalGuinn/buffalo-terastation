# Project Status and Next Steps

Last updated: 2026-03-19

---

## 1. Session Summary (2026-03-19)

What was accomplished in this initial session:

- Identified the SoC as **Annapurna Labs Alpine V2** (ARM Cortex-A57, AArch64) -- correcting earlier ARM32 assumptions
- Extracted DTBs from firmware updater ZIP (v2.98 and v3.08), confirmed DTBs are identical across versions
- Decompiled and annotated the TS51220 device tree (`alpine-ts51220-annotated.dts`)
- Created comprehensive hardware summary with I2C bus map, GPIO pin map, SATA/LED mapping, SerDes lane assignments, PCIe topology, UART assignments, and flash partitions
- Cataloged all kernel drivers from Buffalo's defconfig and classified them (upstream vs. needs-porting vs. droppable)
- Built a phased kernel build strategy document with risk assessment
- Extracted selective rootfs files from SquashFS (boot config, udev rules, Buffalo scripts, micon binaries)
- Set up vanilla kernel source tree (`gpl-source/linux-4.19.75/`)
- Wrote firmware extraction guide with all known decryption keys
- Surveyed community research (QNAP Alpine V2, existing open-source efforts)
- Reviewed Claude Code setup and wrote recommendations for harness improvements
- Initialized git repo, committed all work (3 commits)
- Expanded CLAUDE.md with full project context and conventions

## 2. Current State

### Artifacts that exist

| Category | Files | Status |
|----------|-------|--------|
| **Device trees** | `devicetree/alpine-ts51220.dtb`, `.dts`, `-annotated.dts` | Extracted from real firmware, decompiled, annotated |
| **Device trees** | `alpine-ts5020.dtb`, `.dts`, `alpine-ts3030.dtb`, `.dtb` | Companion models for reference |
| **Device trees** | `alpine-v2-ts5020.dts` | Early/partial DTS (pre-extraction, may be stale) |
| **GPL source** | `gpl-source/linux-4.19.75/` | Vanilla kernel tree (extracted, not patched) |
| **GPL patches** | `gpl-source/v4.19.75-241-g0fb91c28a25c.patch` (AL SDK) | Raw, inverted diff (~384 files) |
| **GPL patches** | `gpl-source/linux-4.19.75_buffalo.patch` (Buffalo) | Raw, inverted diff (~141 files) |
| **Firmware** | `firmware/win298/`, `firmware/win308/` | Original updater ZIPs, extracted |
| **Firmware** | `firmware/win308/extracted/` | DTBs and other extracted components |
| **Rootfs** | `firmware/rootfs/{boot,etc,usr}` | Selective extraction from SquashFS |
| **Research** | `research/*.txt`, `*.pdf`, `*.html` | Prior Google AI Studio work (treat with caution) |
| **Notes** | 8 analysis documents in `notes/` | See notes/CLAUDE.md for index |
| **Git** | 3 commits on main | Clean working tree |

### What has NOT been done yet

- No patches have been applied to the kernel source
- No patches have been un-inverted (corrected) -- `patches/` directory is empty
- No modern kernel source downloaded (6.12 LTS or newer)
- No cross-compilation toolchain set up
- No Docker build environment created
- No `.claude/skills/` or hooks configured
- No rootfs analysis document written (listed in notes index but file doesn't exist)
- Boot config from rootfs (`config-4.19.75-*`) not yet analyzed as a defconfig reference

## 3. Open Items

- **rootfs_analysis.md** -- Listed in `notes/CLAUDE.md` as WIP but the file doesn't exist yet. The rootfs has been extracted to `firmware/rootfs/` and contains valuable data (Buffalo init scripts, udev rules, micon binaries, kernel config, kernel image)
- **Boot config analysis** -- `firmware/rootfs/boot/config-4.19.75-*` is Buffalo's actual running kernel config (160KB). This is the ground truth defconfig and hasn't been parsed into our hardware catalog or build strategy yet.
- **Patch un-inversion** -- Neither the AL SDK patch nor Buffalo patch has been corrected. Need to produce usable forward patches before any kernel work.
- **U-Boot analysis** -- We know U-Boot is in SPI flash partition 0 (3MB) but haven't extracted or analyzed it. Key unknowns: does it support `booti`? Does it enforce signed kernels?
- **Micon protocol** -- `miconapl` and `miconmon` binaries exist in rootfs but haven't been reverse-engineered. Protocol needed for fan/LED/LCD/button control.
- **alpine-v2-ts5020.dts** -- Appears to be an early/partial DTS from before firmware extraction. May be stale or superseded by `alpine-ts51220.dts`. Needs review.

---

## 4. Two Project Tracks

### Track A: Buffalo TeraStation Kernel Build

The actual engineering goal -- run a modern mainline Linux kernel on this hardware.

### Track B: Claude Code Harness Optimization

Meta/tooling work to make Claude Code more effective for this project. Fully independent of Track A.

---

## 5. Track A Next Steps

### Phase 1: Deep Research and Planning (before touching kernel source)

Priority order:

1. **Analyze Buffalo's running kernel config**
   - Parse `firmware/rootfs/boot/config-4.19.75-*` (the actual production .config)
   - Compare against our hardware catalog -- find any drivers we missed
   - Identify which CONFIG options are Buffalo-custom vs. AL SDK vs. upstream
   - This is the single most authoritative reference for "what hardware needs support"

2. **Check latest kernel.org LTS version**
   - Verify whether 6.12 is still the latest LTS or if 6.x has a newer one
   - Check `arch/arm64/boot/dts/amazon/` in that kernel for Alpine V2 DTS status
   - Check if `pcie-al.c`, `alpine-msi`, `al-fic` are still maintained

3. **Analyze mainline Alpine V2 DTS**
   - Download and compare `alpine-v2.dtsi` from mainline against our extracted DTS
   - Identify which nodes are already covered upstream vs. what we need to add
   - This determines how much DTS work is needed

4. **U-Boot investigation**
   - Determine boot sequence: does U-Boot use `booti` or `bootm`?
   - Check for secure boot / kernel signature verification
   - Extract U-Boot environment (if accessible from rootfs or firmware images)
   - Read Buffalo's `fw_updater` binary strings for clues about update process

5. **Un-invert and categorize GPL patches**
   - Process AL SDK patch: extract the out-of-tree driver files (al_eth, AL HAL, thermal, etc.)
   - Process Buffalo patch: separate into droppable (Buffalo NAS) vs. potentially useful
   - Don't apply them yet -- just understand what they contain

6. **Rootfs deep analysis**
   - Write `rootfs_analysis.md` covering: init sequence, micon integration, network setup, storage management
   - Analyze udev rules (`60-buffalo-gpio-pinctrl.rules`, `65-buffalo-storage-internal.rules`, `70-buffalo-micon.rules`, `70-buffalo-net.rules`) for hardware initialization insights
   - Check `buffalo-rc` init script for boot-time hardware setup commands

### Phase 2: Minimal Boot Kernel

Only start this after Phase 1 research is complete.

1. Download target kernel source (6.12 LTS or latest)
2. Set up Docker cross-compilation environment
3. Create minimal defconfig (ARCH_ALPINE + serial + PCIe + AHCI)
4. Adapt DTS for mainline (start from mainline `alpine-v2.dtsi`, add board nodes)
5. Build Image + DTB
6. Test boot via TFTP + UART console (requires physical access to NAS)

### Phase 3: Full Hardware Support

1. Ethernet (Intel PCIe NIC for quick path, or AL eth driver port for native 10GbE)
2. I2C peripherals (should just work with correct DTS)
3. AL Thermal driver port
4. Micon userspace daemon (fan/LED/LCD control)
5. EDAC, NAND, DMA acceleration (nice-to-have)

### Research still needed before building anything

- Is the NAS physically accessible for serial console + TFTP boot testing?
- Is there a PCIe slot available for an Intel NIC (to skip al_eth porting)?
- What is the U-Boot boot command sequence? (Determines kernel image format)
- Does U-Boot enforce signed kernels? (Could be a showstopper)
- What kernel version does mainline Alpine V2 support stabilize at?

---

## 6. Track B Next Steps

### Priority 1: Containerized Build Environment (1-2 hours)

- Create `tools/docker/Dockerfile.kernel-build` with aarch64-linux-gnu toolchain
- Add convenience build script (`tools/build.sh`)
- Test with a trivial arm64 kernel build
- This is a prerequisite for any Track A Phase 2 work

### Priority 2: Custom Skills (1-2 hours)

Create `.claude/skills/` for:
- **firmware-extract** -- Standardized firmware unpacking with known passwords
- **patch-analysis** -- Handle inverted diffs correctly
- **dts-validate** -- Validate DTS after editing (run `dtc`)
- **kernel-config** -- Cross-reference config against hardware catalog

### Priority 3: Hooks (1 hour)

- PostToolUse hook: auto-validate DTS files after Edit/Write operations
- PostToolUse hook: dry-run patch application after editing .patch files
- Pre-commit: compile all DTS files to catch syntax errors

### Priority 4: Security and Permissions Hardening (30 min)

- Add missing permissions: `make`, `patch`, `readelf`, `objdump`, `cpio`, `dd`
- Add deny rule: `dd of=/dev/*`
- Add environment variables: `ARCH=arm64`, `CROSS_COMPILE=aarch64-linux-gnu-`
- Consider removing Playwright MCP server (low value, adds context overhead)

### Priority 5: Workflow Optimizations (30 min)

- StatusLine configuration showing project phase
- Sub-directory CLAUDE.md files for `devicetree/` and `patches/` (partially done)
- Custom agent: `hardware-researcher` for IC identification tasks

---

## 7. Session Resume Instructions

### To continue this project:

```bash
cd ~/Claude/buffalo-terastation
claude --resume    # Resume last session, or start new session in this directory
```

### First things to check in a new session:

1. Claude will auto-read `CLAUDE.md` -- it contains full project context
2. Check `notes/CLAUDE.md` for index of all research documents
3. Read THIS file (`notes/project_status_and_next_steps.md`) for current status
4. Check `git log --oneline` to confirm you're on the right commit

### If continuing Track A:

Start with item 1 from Phase 1: analyze `firmware/rootfs/boot/config-4.19.75-*`

### If continuing Track B:

Start with Priority 1: create the Docker build environment

### Key files to have open:

- `notes/kernel_build_strategy.md` -- the master plan
- `notes/ts51220_hardware_summary.md` -- hardware reference
- `notes/hardware_catalog.md` -- driver-to-hardware mapping
- `devicetree/alpine-ts51220-annotated.dts` -- device tree ground truth

---

## 8. Key Decisions Pending (needs Conrad's input)

1. **Physical access** -- Is the TS51220 physically accessible right now? Can you connect a serial console to UART0 and set up TFTP boot? This determines whether Phase 2 (boot testing) is feasible soon or needs to wait.

2. **PCIe NIC availability** -- Do you have an Intel IGB/IXGBE PCIe NIC to install? This is the difference between "easy ethernet" and "port the AL eth driver" (weeks of work).

3. **Target kernel version** -- Should we go with 6.12 LTS, or check if a newer LTS (6.13+?) exists? Need to verify on kernel.org.

4. **Track priority** -- Do you want to focus on Track A (kernel RE) or Track B (harness optimization) first? They are independent and can be done in any order. Track B makes Track A more efficient, but Track A is the actual goal.

5. **Patch approach** -- For the AL SDK patch (~384 files): should we un-invert the entire thing, or selectively extract only the drivers we need (al_eth, thermal, etc.)? Selective is faster but risks missing dependencies.

6. **U-Boot risk tolerance** -- If U-Boot enforces signed kernels, the options are: (a) find the signing key in firmware, (b) flash a custom U-Boot (risk of bricking), (c) use a different boot path. How risk-tolerant are you with the bootloader?

7. **Scope of rootfs analysis** -- The rootfs contains a lot of Buffalo application-layer stuff (NAS management, iSCSI, DLNA, etc.). How deep should analysis go? Recommend: focus only on hardware-relevant files (init scripts, udev rules, micon) and skip the NAS application layer entirely.
