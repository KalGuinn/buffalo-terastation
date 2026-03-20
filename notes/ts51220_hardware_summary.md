# Buffalo TeraStation TS51220 Hardware Summary

Extracted from device tree `alpine-ts51220.dts` with comparison to TS5020.

## System Overview

| Property | Value |
|----------|-------|
| Model | BUFFALO TS51220 (TS5K2ALV2-AA) |
| Board ID | ts51220_buffalo_rev1.0 |
| SoC | Annapurna Labs Alpine V2 (Amazon) |
| Architecture | ARMv8-A (AArch64) |
| CPU | Quad-core (likely Cortex-A57) |
| L1 D-Cache | 32KB per core, 64B line, 256 sets |
| L1 I-Cache | 48KB per core, 64B line, 256 sets |
| L2 Cache | 2MB shared, 64B line, 2048 sets, 16-way |
| RAM | DDR4, 2 DIMM slots (socketed), size set at boot |
| PSCI | v0.2 via SMC |
| Timer | ARMv8 Generic Timer, 50 MHz |
| Interrupt Controller | GICv3 |
| Thermal Critical | 105 C |
| Disk Bays | 12 |

## Clock Frequencies

| Clock | Frequency | Note |
|-------|-----------|------|
| refclk | 24 MHz | Board crystal oscillator |
| arch-timer | 50 MHz | ARMv8 generic timer counter |
| sbclk | Placeholder (1 MHz in DTB) | Patched by U-Boot; typically 375 MHz |
| nbclk | Placeholder (1 MHz in DTB) | Patched by U-Boot |
| cpuclk | Placeholder (1 MHz in DTB) | Patched by U-Boot |
| SPI flash max | 25 MHz | spi-max-frequency |
| I2C bus | 100 kHz | Both i2c-pld and i2c-gen |

## I2C Bus Map

### i2c-pld (Primary Bus)
Register: `0xfd88_0000`, SPI 21

| Address | Device | Description |
|---------|--------|-------------|
| 0x32 | Epson RX8010SJ | Real-Time Clock |
| 0x54 | DDR4 SPD EEPROM | DIMM 0 (via dram config) |
| 0x55 | DDR4 SPD EEPROM | DIMM 1 (via dram config) |
| 0x57 | 24C64 EEPROM | 8KB — board config, MAC addresses |
| 0x70 | PCA9548 | 8-channel I2C multiplexer (TS51220 only) |

The PCA9548 mux fans out I2C to SFP+ modules and PHY management:
- Channel 1: eth0 10GbE PHY / SFP+ module
- Channel 3: eth2 10GbE PHY / SFP+ module

### i2c-gen (Secondary Bus) — DISABLED
Register: `0xfd89_4000`, SPI 8

## GPIO Pin Map

Each PL061 bank provides 8 pins. `baseidx` is the Linux GPIO base number.

| Bank | Register | SPI | Base Index | Pins | Phandle | Function |
|------|----------|-----|------------|------|---------|----------|
| gpio0 | 0xfd88_7000 | 2 | 504 | 504-511 | 0x16 | SATA host 2 LEDs (pins 0-3) |
| gpio1 | 0xfd88_8000 | 3 | 496 | 496-503 | — | General purpose |
| gpio2 | 0xfd88_9000 | 4 | 488 | 488-495 | 0x14 | SATA host 0 LEDs (pins 4-7) |
| gpio3 | 0xfd88_a000 | 5 | 480 | 480-487 | 0x15 | SATA host 1 LEDs (pins 0-3) |
| gpio4 | 0xfd88_b000 | 6 | 472 | 472-479 | — | General purpose |
| gpio5 | 0xfd89_7000 | 7 | 464 | 464-471 | — | General purpose |
| sgpo  | 0xfd8b_4000 | — | 48  | 48+    | — | Serial GPIO output (shift register) |

### GPIO Initialization at Boot

| GPIO Pin | Direction | Value | Likely Purpose |
|----------|-----------|-------|----------------|
| 28 | Output | Low | PCIe HBA reset (port 0/1) |
| 29 | Output | Low | PCIe HBA reset (port 2) |
| 32 | Output | Low | PCIe HBA reset (port 3) |
| 33 | Output | Low | PCIe HBA reset (secondary) |
| 4 | Input | — | Presence detect |
| 5 | Input | High | Presence detect |

## SATA Port and LED Mapping

### Host 0 — Native SATA (SerDes Group 1, Internal PCIe dev 8)

| Port | Bay | LED GPIO Bank | LED Pin | GPIO Number |
|------|-----|---------------|---------|-------------|
| 0 | 1 | gpio2 (0x14) | 4 | 492 |
| 1 | 2 | gpio2 (0x14) | 5 | 493 |
| 2 | 3 | gpio2 (0x14) | 6 | 494 |
| 3 | 4 | gpio2 (0x14) | 7 | 495 |

### Host 1 — PCIe-attached SAS/SATA HBA (External PCIe)

| Port | Bay | LED GPIO Bank | LED Pin | GPIO Number |
|------|-----|---------------|---------|-------------|
| 0 | 8 | gpio3 (0x15) | 0 | 480 |
| 1 | 7 | gpio3 (0x15) | 1 | 481 |
| 2 | 6 | gpio3 (0x15) | 2 | 482 |
| 3 | 5 | gpio3 (0x15) | 3 | 483 |

### Host 2 — PCIe-attached SAS/SATA HBA (External PCIe)

| Port | Bay | LED GPIO Bank | LED Pin | GPIO Number |
|------|-----|---------------|---------|-------------|
| 0 | 10 | gpio0 (0x16) | 0 | 504 |
| 1 | 9 | gpio0 (0x16) | 1 | 505 |
| 2 | 11 | gpio0 (0x16) | 2 | 506 |
| 3 | 12 | gpio0 (0x16) | 3 | 507 |

Note: LED entries are duplicated across PCI domains 2/3 (host 1) and 3/4 (host 2) to handle variable PCIe enumeration order.

## Ethernet Port Configuration

| Port | Mode | Speed | SerDes Group | Lane | PHY IF | PHY Addr | I2C Mux Ch |
|------|------|-------|-------------|------|--------|----------|------------|
| eth0 | 10g-serial | 10GbE | Group 3 | Lane 2 | XMDIO (clause 45) | 0x08 | 1 |
| eth1 | RGMII | 1GbE | — | — | MDIO (clause 22) | 0x02 | — |
| eth2 | 10g-serial | 10GbE | Group 3 | Lane 0 | XMDIO (clause 45) | 0x00 | 3 |
| eth3 | RGMII | 1GbE | — | — | MDIO (clause 22) | 0x03 | — |

MAC register addresses:
- eth0: `0xfc00_0000` (MAC), `0xfc01_8000` (EC), `0xfc00_5000` (UDMA)
- eth1: `0xfc10_0000` (MAC only)
- eth2: `0xfc20_0000` (MAC), `0xfc21_8000` (EC), `0xfc20_5000` (UDMA)
- eth3: `0xfc30_0000` (MAC only)

## SerDes Lane Assignments

| Group | Interface | Ref Clock | Active Lanes | Assignment |
|-------|-----------|-----------|-------------|------------|
| 0 | pcie_g2x2_pcie_g2x2 | 100 MHz | 0,1,2,3 | PCIe ext port 0 (L0-1) + port 1 (L2-3) |
| 1 | sata | 100 MHz | 0,1,2,3 | SATA host 0, 4 ports (bays 1-4) |
| 2 | pcie_g2x2_pcie_g2x2 | 100 MHz | 0,1,2,3 | PCIe ext port 2 (L0-1) + port 3 (L2-3) |
| 3 | 10gbe | 156.25 MHz | 0,2 | eth2 (L0) + eth0 (L2) |
| 4 | skip | 100 MHz | 0,1 | Unused |

All groups: TX/RX lane polarity inverted, SSC disabled.

## PCIe Topology

### Internal PCIe Bus
- ECAM: `0xfbc0_0000` (1MB)
- MMIO: `0xfe00_0000` (16MB)
- Device 8: SATA host 0 (SPI 53)
- Device 9: SATA host 1 (SPI 54)

### External PCIe Ports

| Port | ECAM Base | IOFIC SPI | Config Offset | MMIO Base | Gen | Width | Status |
|------|-----------|-----------|---------------|-----------|-----|-------|--------|
| 0 | 0xfd80_0000 | SPI 47 | 64KB | 0xc001_0000 | Gen2 | x2 | Enabled |
| 1 | 0xfd82_0000 | SPI 48 | 8KB | 0xc801_0000 | Gen2 | x2 | Enabled |
| 2 | 0xfd84_0000 | SPI 49 | 8KB | 0xd001_0000 | Gen2 | x2 | Enabled |
| 3 | 0xfd90_0000 | SPI 50 | 8KB | 0xd801_0000 | Gen2 | x2 | Enabled |

## UART Assignments

| UART | Register | SPI | Status | Purpose |
|------|----------|-----|--------|---------|
| uart0 | 0xfd88_3000 | 17 | Active | Debug console (115200 baud typical) |
| uart1 | 0xfd88_4000 | 18 | Active | Buffalo Micon (LCD, buttons, fans, buzzer) |
| uart2 | 0xfd88_5000 | 19 | Disabled | Unused |
| uart3 | 0xfd88_6000 | 20 | Disabled | Unused |

## Flash Storage

### SPI Flash (4MB)

| Partition | Offset | Size | Label |
|-----------|--------|------|-------|
| 0 | 0x000000 | 3 MB | al_boot (U-Boot primary) |
| 1 | 0x300000 | 832 KB | feature_reserved |
| 2 | 0x3D0000 | 128 KB | nas-feature |
| 3 | 0x3F0000 | 64 KB | firmware_hash |

### NAND Flash (~1GB)

| Partition | Offset | Size | Label |
|-----------|--------|------|-------|
| 0 | 0x000000 | 3 MB | al_boot_nand (secondary boot) |
| 1 | 0x300000 | 2 MB | device_tree |
| 2 | 0x500000 | 15 MB | linux_kernel |
| 3 | 0x1400000 | 30 MB | initrd |
| 4 | 0x3200000 | ~972 MB | ubifs (root filesystem) |

## Key Differences from TS5020

| Feature | TS51220 | TS5020 |
|---------|---------|--------|
| Disk Bays | 12 | 8 (max) |
| SATA Controllers | 1 native + 2 PCIe HBA | 2 native (groups 1+2) |
| SerDes Group 2 | PCIe Gen2 x2 + x2 | SATA (4 ports) |
| 10GbE Ports | 2 (lanes 0+2) | 1 (lane 2 only) |
| Ethernet port2 | Enabled (10GbE) | Not present |
| RGMII PHY addrs | 0x02, 0x03 | 0x04, 0x05 |
| I2C Mux (PCA9548) | Present at 0x70 | Not present |
| PCIe ext ports | All 4 enabled, Gen2 x2 | Only port 0 (Gen2 x1) |
| SATA LED count | 20 entries (12 bays, dual domain) | 8 entries (8 bays) |
| GPIO init pins | 28,29,32,33,4,5 | 28,4 |
| SerDes tuning IDs | @1220R (nas-pid 0x2053) | @820D/@620D/@420D/@220D/@420R |
| NAS Product ID | 0x2053 | 0x2048-0x2052 (variant) |

## Phandle Reference Table

| Phandle | Label | Description |
|---------|-------|-------------|
| 0x01 | gic_main | GICv3 interrupt controller |
| 0x02 | msix | MSI-X controller |
| 0x03 | cpu_sleep_state | CPU idle state |
| 0x04 | l2_cache | Shared L2 cache (2MB) |
| 0x05 | cpu0 | CPU core 0 |
| 0x06 | cpu1 | CPU core 1 |
| 0x07 | cpu2 | CPU core 2 |
| 0x08 | cpu3 | CPU core 3 |
| 0x09 | sbclk | South-bridge peripheral clock |
| 0x0a | sysfab_intc | System fabric interrupt controller |
| 0x0b | syserr_intc | System error interrupt controller |
| 0x0c | wdt0 | Watchdog timer 0 (reboot) |
| 0x0d | iofic_pcie_ext0 | PCIe port 0 IOFIC |
| 0x0e | iofic_pcie_ext1 | PCIe port 1 IOFIC |
| 0x0f | iofic_pcie_ext2 | PCIe port 2 IOFIC |
| 0x10 | iofic_pcie_ext3 | PCIe port 3 IOFIC |
| 0x11 | thermal_sensor | On-die thermal sensor |
| 0x12 | pinmux_nand_8 | NAND 8-bit pin mux |
| 0x13 | pinmux_nand_cs_0 | NAND chip select 0 pin mux |
| 0x14 | gpio2 | GPIO bank 2 (SATA host 0 LEDs) |
| 0x15 | gpio3 | GPIO bank 3 (SATA host 1 LEDs) |
| 0x16 | gpio0 | GPIO bank 0 (SATA host 2 LEDs) |
