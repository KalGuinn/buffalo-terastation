# Known Hardware Limitations & Open DTS Questions

_Last reviewed: 2026-04-27_

Items that are enabled in Buffalo's defconfig but whose register addresses, interrupt
numbers, or device tree bindings could not be determined from source code alone.

Most of these were resolved when the v2.98 firmware DTBs were extracted and decompiled
into [`devicetree/alpine-ts51220.dts`](../../devicetree/alpine-ts51220.dts) — the device
tree itself is now the ground truth. The items below are the remaining gaps that the
DTS does not answer (typically because the binding is custom Annapurna Labs, the device
is on a runtime-discoverable bus like PCIe, or the answer requires a running system).

**Status legend:** `open` (unresolved), `resolved-by-dts` (answered by the extracted
DTS), `runtime-only` (only answerable from a booted system).

---

## Critical (block booting or major features)

### 1. I2C Controller Base Address and IRQ
- **Status**: resolved-by-dts — controller nodes are present in `alpine-ts51220.dts` (`i2c@fd880000` and `i2c@fd894000`); IRQ lines are wired in the same nodes.
- **Config**: CONFIG_I2C_DESIGNWARE_PLATFORM=y
- **Issue**: The SDK uses `AL_I2C_PLD_BASE` (PBS + 0x00000 = 0xfd880000) and `AL_I2C_GEN_BASE` (PBS + 0x14000 = 0xfd894000), but we don't know which instance is used on the TS5020 or which IRQ lines they use.

### 2. I2C Bus Topology
- **Status**: resolved-by-dts — PCA9548 mux at addr 0x70 with EEPROM, RX8010 RTC, LM75 sensors, PCA953X GPIO expanders, and Infineon TPM all enumerated in the DTS. See `alpine-ts51220-annotated.dts` for the human-readable channel/address map.
- **Config**: CONFIG_I2C_MUX_PCA954x=y, CONFIG_EEPROM_AT24=y, CONFIG_RTC_DRV_RX8010=y, CONFIG_SENSORS_LM75=y, CONFIG_GPIO_PCA953X=y, CONFIG_TCG_TIS_I2C_INFINEON=y

### 3. GPIO Pin Assignments
- **Status**: resolved-by-dts — power button, reset button, status LEDs, per-disk LEDs, fan control, and buzzer are all in the DTS. See the GPIO map section of `notes/hardware/ts51220_hardware_summary.md`.
- **Config**: CONFIG_GPIO_DWAPB=y, CONFIG_KEYBOARD_GPIO=y, CONFIG_LEDS_GPIO=y

### 4. Memory Size and Layout
- **Status**: open — DTS specifies a placeholder; actual DRAM size depends on the SKU. TS51220RH9612 ships with 8 GB ECC DDR4 per Buffalo's datasheet, but this should be verified against U-Boot env or `/proc/meminfo` on a running unit.

### 5. NAND Controller
- **Status**: runtime-only — `CONFIG_MTD_NAND_AL=y` is set, but the AL HAL NAND driver uses a handle init pattern without DT bindings. Need a running dmesg or SDK board init code to confirm.
- **Config**: CONFIG_MTD_NAND_AL=y

---

## Moderate (needed for full functionality)

### 6. SPI Controller Configuration
- **Status**: partial — base 0xfd882000 is in the DTS as `spi@fd882000`. IRQ, clock, and CS GPIO are wired in the same node. SPI NOR partition table is not yet documented; check U-Boot `mtdparts`.
- **Config**: CONFIG_SPI_DESIGNWARE=y, CONFIG_SPI_DW_MMIO=y

### 7. Watchdog Base Address
- **Status**: resolved-by-dts — SP805 watchdog nodes are present in the DTS with their PBS-relative offsets explicit.
- **Config**: CONFIG_ARM_SP805_WATCHDOG=y

### 8. Thermal Sensor
- **Status**: open — `CONFIG_AL_THERMAL_V2/V3=y` are out-of-tree drivers with no upstream DT binding. The DTS contains thermal nodes but the compatible string is `annapurna,al-thermal` (custom). Mainline port will need to either upstream the binding or use a generic thermal driver.
- **Config**: CONFIG_AL_THERMAL_V2=y, CONFIG_AL_THERMAL_V3=y

### 9. Ethernet Controller Details
- **Status**: runtime-only — AL ethernet is PCI-based, not DT-matched. Port count, PHY type (Aquantia/MaxLinear), and SerDes config are only visible from a booted system via `lspci`/`ethtool`.
- **Config**: CONFIG_NET_AL_ETH=y, CONFIG_NET_AL_LM=y

### 10. R8125 2.5GbE NIC
- **Status**: open — Realtek out-of-tree driver. Confirmed present in Buffalo's GPL release as a separate driver tree. Mainline `r8169` may work, but the vendor explicitly chose `r8125` so behavior may differ.
- **Config**: CONFIG_R8125=y

### 11. USB Controller Topology
- **Status**: resolved-by-dts — xHCI/DWC3 controllers and their register windows are in the DTS. Port count and USB3 availability are runtime-only.
- **Config**: CONFIG_USB_XHCI_PLATFORM=y, CONFIG_USB_DWC3_OF_SIMPLE=y

### 12. PCIe Topology
- **Status**: partial — DTS describes the internal PCIe controllers (carrying SATA, ETH, SSM). External slot count and what's connected to each is runtime-only.
- **Config**: CONFIG_PCI_INTERNAL_ALPINE=y, CONFIG_PCI_EXTERNAL_ALPINE=y

---

## Low priority (non-essential for booting)

### 13. EDAC Register Addresses
- **Status**: open — custom AL EDAC drivers, no upstream binding. System boots without EDAC; can be added later.
- **Config**: CONFIG_EDAC_AL_L1/L2/MC/IOCACHE=y

### 14. Fabric Interrupt Controller Details
- **Status**: open — custom AL interrupt aggregators (FIC, IOFIC, system fabric). Likely required for correct IRQ routing once moving past PCI-discovered interrupts.
- **Config**: CONFIG_AL_FIC=y, CONFIG_AL_SYSTEM_FABRIC=y, CONFIG_ALPINE_IOFIC=y

### 15. Micon V3 Protocol Details
- **Status**: resolved — full command set documented in [`notes/firmware/rootfs_analysis.md`](../firmware/rootfs_analysis.md), extracted from the `miconapl`/`miconmon` binaries.

### 16. SGPO (Serial GPIO) Controller
- **Status**: open — `AL_PBS_SGPO_BASE` at 0xfd8b4000 exists; no DT bindings known. Likely shift-register-based status output. Low priority unless a feature depends on it.

### 17. DFX (Debug/Diagnostic) Block
- **Status**: open — present at 0xfd8e0000 in the SDK; purpose unclear. May be needed for SoC ID / eFuse reads. Low priority.

---

## Recommended path to close remaining `open` items

1. **Boot a stock 4.19.75 kernel and capture full dmesg** — resolves nearly all `runtime-only` items at once.
2. **`lspci -vvv` and `lsusb -t`** on a booted system — completes the PCIe and USB topology.
3. **U-Boot `printenv`** — completes memory size and SPI NOR partition table.
4. **For thermal/EDAC/SGPO/DFX**: read the AL HAL source in `gpl-source/v4.19.75-241-g0fb91c28a25c.patch` (after un-inversion); the bindings live in the driver, not the DTS.
