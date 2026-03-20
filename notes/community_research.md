# Alpine V2 / Buffalo TeraStation TS5020 Community Research

Date: 2026-03-19

## Executive Summary

The Annapurna Labs Alpine V2 is a relatively niche SoC with limited mainline
Linux support. The upstream kernel (as of 4.19.75 and later) contains only a
minimal device tree (EVP board) and MSI interrupt controller driver. The bulk
of hardware support comes from Amazon/Annapurna Labs' proprietary SDK, which
NAS vendors (Buffalo, QNAP, Synology, Asustor) incorporate via large
out-of-tree patch sets. Community efforts to run mainline Linux on these
devices are sparse but do exist.

**NOTE:** Web search and web fetch were unavailable during this research
session. The findings below combine local GPL source analysis with prior
knowledge. Sections marked [NEEDS VERIFICATION] should be confirmed with
live web searches.

---

## 1. Mainline Kernel Alpine V2 Support (Local Analysis)

### 1.1 Device Tree Files in Kernel 4.19.75

Only two DTS/DTSI files exist upstream for Alpine V2:

- `arch/arm64/boot/dts/al/alpine-v2.dtsi` — SoC-level include
- `arch/arm64/boot/dts/al/alpine-v2-evp.dts` — Evaluation Platform board

The DTSI is extremely minimal. It defines:
- 4x Cortex-A57 CPUs with PSCI
- GICv3 interrupt controller at 0xf0200000
- PCI host (ECAM generic) at 0xfbc00000 with two SATA legacy interrupts
- Alpine MSI controller at 0xfbe00000
- 4x ns16550a UARTs (0x1883000-0x1886000, behind io-fabric simple-bus)
- 4x ARM SP804 timers
- PMU, arch timer
- Fixed 1MHz sbclk

**What is MISSING from the upstream DTSI** (but known to exist on real hardware):
- Ethernet (al,eth — Annapurna Labs custom MAC)
- SATA/AHCI controller nodes (beyond PCI-based discovery)
- I2C controllers (DesignWare i2c)
- GPIO controllers (DesignWare APB GPIO)
- SPI controllers
- NAND/MTD
- Thermal sensors
- Watchdog (SP805)
- RTC
- DMA engine
- Crypto/SSM accelerator
- Pin control / pin mux
- Clock controllers (beyond the stub fixed-clock)
- Power management / reset controller
- PCIe root complex details (internal + external)

### 1.2 Compatible Strings and Drivers

Upstream drivers using "al,alpine" compatible strings:
- `drivers/irqchip/irq-alpine-msi.c` — "al,alpine-msix"
- `arch/arm/mach-alpine/` — Alpine V1 (Cortex-A15) platform code

DT binding docs:
- `Documentation/devicetree/bindings/arm/al,alpine.txt`
- `Documentation/devicetree/bindings/arm/cpu-enable-method/al,alpine-smp`
- `Documentation/devicetree/bindings/interrupt-controller/al,alpine-msix.txt`

### 1.3 Kconfig for Alpine

- `arch/arm64/Kconfig.platforms`: `ARCH_ALPINE` selects `ALPINE_MSI if PCI`
- No alpine-v2 defconfig exists in mainline

### 1.4 Alpine V1 (ARM32) for Reference

The Alpine V1 (Cortex-A15 based, used in TS5010/TS3010/TS7010) has slightly
more upstream support:
- `arch/arm/boot/dts/alpine.dtsi` — V1 SoC DTSI (GICv2, two UARTs, PCIe, MSI)
- `arch/arm/boot/dts/alpine-db.dts` — V1 development board
- `arch/arm/mach-alpine/` — SMP, CPU PM, machine init

---

## 2. Buffalo GPL Source Analysis (TS5020)

### 2.1 Key Findings from Buffalo's Patches

The GPL source contains two critical patch files:

1. **`v4.19.75-241-g0fb91c28a25c.patch`** — Annapurna Labs SDK patch (384 files)
   This is the Amazon/Annapurna Labs SDK applied on top of kernel 4.19.75.
   It adds extensive driver support including:
   - `drivers/net/ethernet/al/` — Full AL Ethernet HAL (al_mod_hal_eth_*)
   - `drivers/ata/` — AHCI Alpine extensions (AHCI_ALPINE, AHCI_ALPINE_SSS)
   - `drivers/dma/` — AL DMA engine
   - `drivers/crypto/` (al_ssm_pcie) — Security/crypto accelerator
   - `drivers/edac/` — AL L1 EDAC
   - `drivers/thermal/` — AL thermal (AL_THERMAL_V2, AL_THERMAL_V3)
   - `drivers/misc/` — AL HAL, FIC, system fabric, system error
   - `drivers/irqchip/` — GICv3 modifications
   - `drivers/pci/` — AL PCIe extensions (internal, external, error handling)
   - `drivers/mtd/` — NAND and SPI NOR modifications
   - `drivers/i2c/` — I2C core modifications
   - Power reset: POWER_RESET_ALPINE

2. **`linux-4.19.75_buffalo.patch`** — Buffalo's own modifications
   Adds the `buffalo/` directory tree with:
   - `buffalo/arch/arm64/configs/buffalo_ts5020_defconfig` (6031 lines)
   - `buffalo/arch/arm64/plat-alpine-v2/sysfs.c` — Creates /sys/class/ts5020
   - `buffalo/drivers/` — Buffalo core platform, kernevnt, micon_v3
   - Buffalo Kconfig options (UPS, BTRFS extensions, error counting, etc.)

### 2.2 TS5020 Hardware Configuration (from defconfig)

Key hardware-related configs enabled in buffalo_ts5020_defconfig:

| Subsystem | Config | Notes |
|-----------|--------|-------|
| SoC | ARCH_ALPINE | Annapurna Labs Alpine V2 |
| Platform | BUFFALO_ALPINE_V2_PLATFORM | Buffalo platform sysfs |
| Platform ID | ALPINE_PLATFORM="ALPINE_V2" | |
| SATA | SATA_AHCI=y, AHCI_ALPINE=y, AHCI_ALPINE_SSS=y | Staggered spinup |
| Ethernet | NET_AL_ETH=y, AL_ETH_ALLOC_FRAG=y | AL custom ethernet |
| Link Manager | NET_AL_LM=y | Ethernet link management |
| I2C | I2C_DESIGNWARE_PLATFORM=y | DesignWare I2C |
| I2C Mux | I2C_MUX_PCA954x=y | PCA954x I2C multiplexer |
| GPIO | GPIO_DWAPB=y, GPIO_PCA953X=y | DW APB + PCA953x expander |
| GPIO Keyboard | KEYBOARD_GPIO=y | Likely front panel buttons |
| RTC | RTC_DRV_DS1307=y | DS1307 I2C RTC |
| Watchdog | ARM_SP805_WATCHDOG=y | SP805 watchdog |
| Thermal | AL_THERMAL_V2=y, AL_THERMAL_V3=y | AL thermal sensors |
| Power | POWER_RESET_ALPINE=y | Alpine power/reset |
| PCIe | PCI_INTERNAL_ALPINE=y, PCI_EXTERNAL_ALPINE=y | Internal + external PCIe |
| DMA | AL_DMA=m | AL DMA engine |
| Crypto | AL_SSM_PCIE=y | Security subsystem |
| EDAC | (likely in SDK patch) | L1 EDAC |
| Pinctrl | PINCTRL_SINGLE=y | Single-register pin control |
| SPI NOR | (m25p80 driver modified) | SPI NOR flash for boot |
| NAND | (raw NAND modified) | NAND flash |
| MDIO | OF_MDIO=y, MVMDIO=y, MDIO_BUS_MUX_MMIOREG=y | Network PHY management |
| Filesystem | BTRFS (with Buffalo/Synology extensions) | Default filesystem |
| Encryption | DM_CRYPT=y, ECRYPTFS (with key wrap) | Disk encryption |

### 2.3 Micon (Micro-controller) Interface

Buffalo uses a "micon" (micro-controller) for hardware management:
- `buffalo/micon_v3.h` — Micon V3 interface header
- Functions: `miconCntl_PowerOff()`, `miconCntl_Reboot()`
- Exposed via `/proc/buffalo/micon` and `/proc/buffalo/miconint_en`
- Handles: power control, fan control, LED control, UPS management
- This is likely a serial/I2C-connected microcontroller on the mainboard

### 2.4 Build System Details

From the debianize.sh script and README:
- ARCH: arm64
- Cross compiler: aarch64-linux-gnu-
- DTS used: `alpine-v2-evp.dts` (the only upstream one!)
- Build host: root@buffalo.jp
- Ubuntu 18.04 base (bionic, from package list)
- Kernel version: 4.19.75-buffalo

**Critical insight**: Buffalo uses the generic `alpine-v2-evp.dts` as their
device tree base. The actual hardware configuration likely comes from U-Boot
passing a DTB at boot time (possibly modified/encrypted), or they may use
ACPI tables instead of DT for some peripherals, or the SDK patch may add
device nodes programmatically.

### 2.5 TeraStation Model Lineage

From the README-TSx010.txt found in the patch:
- **TS[537]010 series** — Alpine V1 (ARM32, Cortex-A15), kernel 4.1.37
  - Based on Annapurna SDK 6.1 (tag: al_storage_adv-al-V_6.1.3-5851039)
  - DEFCONFIG: buffalo_ts5010_defconfig
- **TS5020 series** — Alpine V2 (ARM64, Cortex-A57), kernel 4.19.75
  - Based on newer Annapurna SDK (v4.19.75-241-g0fb91c28a25c)
  - DEFCONFIG: buffalo_ts5020_defconfig (based on alpine_v2_defconfig)

---

## 3. QNAP and Alpine V2 NAS Models

### 3.1 QNAP Models Using Alpine V2 [NEEDS VERIFICATION]

Based on prior knowledge, the following QNAP models are believed to use
Annapurna Labs Alpine V2 (AL-524 or AL-324) SoCs:

- **QNAP TS-x31P3** series — Alpine AL-314 (V2, quad A57)
- **QNAP TS-x32PXU** series — Alpine AL-324 (V2)
- **QNAP TS-431X3** — Alpine AL-314
- **QNAP TS-431KX** — Alpine AL-214
- **QNAP TS-831X** — Alpine AL-314 (possibly V1)
- **QNAP TS-1232PXU** — Alpine AL-324

Note: There is some confusion in the community between Alpine V1 (AL-212/AL-514,
Cortex-A15) and Alpine V2 (AL-324/AL-524, Cortex-A57). The "AL-3xx" numbering
indicates V2 (ARM64), while "AL-2xx/5xx" may be either V1 or V2 depending on
the specific part.

### 3.2 Other NAS Vendors Using Alpine SoCs

- **Synology** — Some models use Alpine V1 (e.g., DS1517+, DS918+)
- **Asustor** — Some models use Alpine SoCs
- **Western Digital** — Some My Cloud models

---

## 4. Community Projects and Resources

### 4.1 GitHub User "1000001101000" [NEEDS VERIFICATION]

This user (also known as "Binarysequence") is known in the ARM NAS community
for reverse engineering and porting Linux to various NAS devices. Repos to
check:

- Likely has repositories related to Marvell Armada NAS devices
- May have Buffalo LinkStation/TeraStation related work
- **Action needed**: Visit https://github.com/1000001101000 and enumerate
  all repositories. Look specifically for:
  - Any Alpine or Annapurna Labs related repos
  - Buffalo NAS repos
  - Device tree files for NAS hardware
  - Firmware extraction tools

### 4.2 BuffaloNAS Wiki [NEEDS VERIFICATION]

- URL: https://buffalonas.miraheze.org/wiki/
- The "Extract Boot Files from Stock Firmware" page likely documents:
  - How to extract initrd and kernel from Buffalo firmware update files
  - Possibly decryption methods for Buffalo's firmware encryption
  - Boot process details
- **Action needed**: Fetch and review this page

### 4.3 Known Community Members [NEEDS VERIFICATION]

- **1000001101000 / Binarysequence** — NAS Linux porting
- **Antoine Tenart** — Original Alpine V2 upstream DTS author (Free Electrons / Bootlin)
- **Hanna Hawa (hhhawa@amazon.com)** — Amazon/Annapurna Labs kernel maintainer
  (from MAINTAINERS file in SDK patch, authored AL L1 EDAC driver)
- **torvald (Tobias Waldekranz)** — Some QNAP Alpine work [NEEDS VERIFICATION]
- Various QNAP community forum members

### 4.4 Relevant Mailing List / Forum Threads [NEEDS VERIFICATION]

Potential resources to search:
- LKML (linux-kernel mailing list) for "alpine-v2" patches
- linux-arm-kernel mailing list
- QNAP Club forums
- forum.openwrt.org for Alpine discussions
- nas-forum.com
- SNBForums (smallnetbuilder.com/forums)

---

## 5. OpenWrt and Debian Alpine V2 Support

### 5.1 OpenWrt [NEEDS VERIFICATION]

OpenWrt does not have official Alpine V2 support as of early 2025. The Alpine
V1 (ARM32) had some experimental/community support. The main challenges are:
- Lack of complete upstream device trees
- Proprietary ethernet driver (al_eth)
- Proprietary PCIe driver extensions

### 5.2 Debian ARM64 [NEEDS VERIFICATION]

Standard Debian arm64 images can potentially boot on Alpine V2 hardware if:
- A correct device tree is provided
- The ethernet driver is available (either from SDK or a reverse-engineered version)
- U-Boot can load the kernel and DTB

Some community members have reported running Debian on QNAP Alpine devices
by extracting the vendor DTB and using it with a mainline kernel plus the
AL ethernet driver compiled out-of-tree.

---

## 6. Firmware Encryption and Extraction

### 6.1 Buffalo Firmware Encryption [NEEDS VERIFICATION]

Buffalo NAS firmware updates typically use:
- AES encryption for firmware images
- Custom headers with checksums
- The firmware updater (.exe on Windows) contains the actual install image
- Tools like `binwalk` can sometimes extract the kernel and ramdisk after decryption

Known approaches:
- Extract from the Windows updater executable
- Use Buffalo's own tools on a running system
- Serial console access to U-Boot for direct flash reading
- Some models use well-known encryption keys that have been documented
  by the community

### 6.2 DTB Extraction Strategy

Since Buffalo uses `alpine-v2-evp.dts` at build time, the actual device tree
used at runtime likely comes from one of:
1. **U-Boot**: U-Boot may have a built-in DTB or load one from flash
2. **Boot partition**: DTB stored alongside kernel in boot partition
3. **Embedded in kernel**: FIT image containing both kernel and DTB
4. **ACPI**: Some Alpine V2 systems use ACPI instead of or alongside DT

The most promising approach for the TS5020:
- Get serial console access and dump U-Boot environment
- Extract DTB from running system: `cat /sys/firmware/fdt > board.dtb`
  then decompile with `dtc -I dtb -O dts board.dtb`
- Extract from firmware update image

---

## 7. Key Upstream Drivers Relevant to Alpine V2

These mainline drivers are used by the TS5020 (from defconfig analysis):

| Driver | Module | Purpose |
|--------|--------|---------|
| ns16550a | 8250/serial | UART (console + micon?) |
| arm,gic-v3 | irq-gic-v3 | Interrupt controller |
| al,alpine-msix | irq-alpine-msi | MSI controller |
| pci-host-ecam-generic | pci-host-generic | PCIe host |
| arm,sp804 | timer-sp804 | Timers |
| arm,sp805 | sp805_wdt | Watchdog |
| snps,dw-apb-gpio | gpio-dwapb | GPIO |
| snps,designware-i2c | i2c-designware | I2C controller |
| nxp,pca9548 | i2c-mux-pca954x | I2C mux |
| nxp,pca9555 | gpio-pca953x | GPIO expander |
| dallas,ds1307 | rtc-ds1307 | RTC |
| pinctrl-single | pinctrl-single | Pin mux |

These drivers are OUT-OF-TREE (from SDK, not upstream):
| Driver | Config | Purpose |
|--------|--------|---------|
| al_eth | NET_AL_ETH | Ethernet MAC |
| al_thermal | AL_THERMAL_V2/V3 | Thermal monitoring |
| al_dma | AL_DMA | DMA engine |
| al_ssm | AL_SSM_PCIE | Crypto accelerator |
| ahci_alpine | AHCI_ALPINE | Enhanced AHCI for Alpine |
| al_pcie | PCI_INTERNAL/EXTERNAL_ALPINE | PCIe controller |
| al_hal | AL_HAL | Hardware abstraction layer |
| al_fic | AL_FIC | Fabric interrupt controller |
| power-reset-alpine | POWER_RESET_ALPINE | Power/reset control |

---

## 8. Recommended Next Steps

### High Priority
1. **Extract the runtime DTB** from a running TS5020 system via
   `/sys/firmware/fdt` or `/proc/device-tree` — this is the single most
   valuable artifact for the project
2. **Reverse the SDK patch** (`v4.19.75-241-g0fb91c28a25c.patch`) to get
   the actual AL driver source code for building out-of-tree modules
3. **Search for QNAP GPL sources** — QNAP releases GPL source for their
   NAS products; the Alpine V2 models will have the same SDK and may
   include additional DTS files for specific boards

### Medium Priority
4. **Check GitHub user 1000001101000** for any relevant repos (web access needed)
5. **Review BuffaloNAS wiki** for firmware extraction guides (web access needed)
6. **Search for newer mainline kernels** (5.x, 6.x) for any additional
   Alpine V2 upstream work — Amazon may have upstreamed more drivers
7. **Check QNAP GPL source** — download from https://sourceforge.net/projects/qnapgpl/
   for Alpine V2 models (TS-x31P3, etc.)

### Lower Priority
8. Look for the `alpine_v2_defconfig` that buffalo_ts5020_defconfig was
   based on — this is likely in the Annapurna SDK, not upstream
9. Investigate ACPI tables on the TS5020 — the SDK patch may add ACPI support
10. Research the micon (micro-controller) interface for fan/LED/power control

---

## 9. File Locations in This Project

Key files analyzed during this research:

- `/Users/conrad/Claude/buffalo-terastation/gpl-source/linux-4.19.75_buffalo.patch`
  — Buffalo's patch (inverted diff: removals = Buffalo additions)
- `/Users/conrad/Claude/buffalo-terastation/gpl-source/v4.19.75-241-g0fb91c28a25c.patch`
  — Annapurna Labs SDK patch (384 files, includes all AL drivers)
- `/Users/conrad/Claude/buffalo-terastation/gpl-source/linux-4.19.75/arch/arm64/boot/dts/al/alpine-v2.dtsi`
  — Upstream Alpine V2 SoC DTSI (minimal)
- `/Users/conrad/Claude/buffalo-terastation/gpl-source/linux-4.19.75/arch/arm64/boot/dts/al/alpine-v2-evp.dts`
  — Upstream EVP board DTS
- `/Users/conrad/Claude/buffalo-terastation/gpl-source/ts5020_gpl_installed_packages_list.txt`
  — Ubuntu 18.04 (bionic) package list from running TS5020

---

## Appendix A: Alpine V1 vs V2 Comparison

| Feature | Alpine V1 | Alpine V2 |
|---------|-----------|-----------|
| CPU | Cortex-A15 (ARMv7) | Cortex-A57 (ARMv8/AArch64) |
| GIC | GICv2 | GICv3 |
| Interrupt controller base | 0xfb001000 | 0xf0200000 |
| UART base | 0xfd883000 | 0xfc000000 + 0x1883000 |
| PCIe ECAM | 0xfbc00000 | 0xfbc00000 |
| MSI base SPI | 96 | 160 |
| MSI num SPIs | 64 | 160 |
| Kernel arch | arm (32-bit) | arm64 |
| Buffalo models | TS5010, TS3010, TS7010 | TS5020 |
| SDK base kernel | 4.1.37 | 4.19.75 |
| Annapurna SDK | 6.1 | Newer (version TBD) |
