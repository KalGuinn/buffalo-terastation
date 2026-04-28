# DTS Unknowns - TS5020 Device Tree Gaps

Items that are enabled in defconfig but whose register addresses, interrupt
numbers, or device tree bindings could not be determined from source code alone.

---

## Critical Unknowns (block booting or major features)

### 1. I2C Controller Base Address and IRQ
- **Config**: CONFIG_I2C_DESIGNWARE_PLATFORM=y
- **Issue**: The SDK uses `AL_I2C_PLD_BASE` (PBS + 0x00000 = 0xfd880000) and
  `AL_I2C_GEN_BASE` (PBS + 0x14000 = 0xfd894000), but we don't know which
  instance is used on the TS5020 or which IRQ lines they use.
- **Resolution**: Boot the stock kernel with `earlycon`, check dmesg for i2c
  probe messages, or dump the DTB from U-Boot memory.

### 2. I2C Bus Topology
- **Config**: CONFIG_I2C_MUX_PCA954x=y, CONFIG_EEPROM_AT24=y, CONFIG_RTC_DRV_RX8010=y,
  CONFIG_SENSORS_LM75=y, CONFIG_GPIO_PCA953X=y, CONFIG_TCG_TIS_I2C_INFINEON=y
- **Issue**: We know these devices exist on I2C but don't know:
  - Which I2C bus each is on
  - I2C slave addresses
  - Which PCA954x mux variant (PCA9548? PCA9544?)
  - Which channel of the mux each device is on
- **Resolution**: `i2cdetect` scan on running system, or read board schematics.

### 3. GPIO Pin Assignments
- **Config**: CONFIG_GPIO_DWAPB=y, CONFIG_KEYBOARD_GPIO=y, CONFIG_LEDS_GPIO=y
- **Issue**: No way to determine which GPIO pins map to:
  - Power button
  - Reset button
  - Status LEDs (power, info, error)
  - Per-disk activity LEDs
  - Fan control
  - Buzzer
- **Resolution**: Reverse engineer from running system GPIO sysfs, or from micon
  protocol observation.

### 4. Memory Size and Layout
- **Issue**: Don't know actual DRAM size. Could be 2GB, 4GB, or 8GB ECC DDR4.
- **Resolution**: Check U-Boot environment, or `cat /proc/meminfo` on running system.

### 5. NAND Controller
- **Config**: CONFIG_MTD_NAND_AL=y
- **Issue**: Register base address unknown. The AL HAL NAND driver uses a handle
  init pattern without clear DT bindings. Unknown if it has a DT compatible string
  or is probed via platform code.
- **Resolution**: Check dmesg for MTD/NAND messages, or search for platform device
  registration in the SDK board init code.

---

## Moderate Unknowns (needed for full functionality)

### 6. SPI Controller Configuration
- **Config**: CONFIG_SPI_DESIGNWARE=y, CONFIG_SPI_DW_MMIO=y
- **Issue**: Know base is 0xfd882000 (PBS + 0x02000) but need:
  - IRQ number
  - Clock reference
  - Chip-select GPIO (if any)
  - SPI NOR flash part number and partition table
- **Resolution**: Check U-Boot `mtdparts` env variable, dmesg output.

### 7. Watchdog Base Address
- **Config**: CONFIG_ARM_SP805_WATCHDOG=y
- **Issue**: The SDK defines `AL_WD_BASE(idx)` with a formula involving PBS base
  but the exact offset for each WDT index is not clear from the patch.
- **Resolution**: Search for WDT probe in dmesg, or look at more HAL header detail.

### 8. Thermal Sensor
- **Config**: CONFIG_AL_THERMAL_V2=y, CONFIG_AL_THERMAL_V3=y
- **Issue**: Custom Annapurna Labs thermal driver, not upstream. Register base
  and DT compatible string unknown. The HAL uses `al_thermal_sensor_handle_init()`
  with a register pointer.
- **Resolution**: Check the full al_thermal_v2.c driver source for DT bindings.

### 9. Ethernet Controller Details
- **Config**: CONFIG_NET_AL_ETH=y, CONFIG_NET_AL_LM=y
- **Issue**: The AL Ethernet is PCI-based (not DT-matched), so no compatible
  string needed. But we need to know:
  - How many ports are active on the TS5020
  - Which PHY is used (likely Aquantia or MaxLinear based on PHY configs)
  - SerDes configuration
- **Resolution**: `lspci`, `ethtool`, and `ip link` on running system.

### 10. R8125 2.5GbE NIC
- **Config**: CONFIG_R8125=y
- **Issue**: This is a Realtek out-of-tree driver (not the upstream r8169).
  It's a PCIe device, so no DT entry needed, but we need to know if the
  Buffalo firmware carries this driver as a separate module.
- **Resolution**: Check if the driver source is in the GPL release.

### 11. USB Controller Topology
- **Config**: CONFIG_USB_XHCI_PLATFORM=y, CONFIG_USB_DWC3_OF_SIMPLE=y
- **Issue**: USB host controllers (xHCI/DWC3) likely on internal PCIe or
  platform bus. Need:
  - Register addresses if platform-bus
  - Number of USB ports
  - Whether USB3 is available
- **Resolution**: `lsusb -t` on running system, dmesg for HCD probe.

### 12. PCIe Topology
- **Config**: CONFIG_PCI_INTERNAL_ALPINE=y, CONFIG_PCI_EXTERNAL_ALPINE=y
- **Issue**: How many external PCIe slots? What's connected?
  Internal PCIe carries SATA, ETH, SSM. External likely carries R8125.
- **Resolution**: `lspci -tv` on running system.

---

## Low-priority Unknowns (non-essential for booting)

### 13. EDAC Register Addresses
- **Config**: CONFIG_EDAC_AL_L1/L2/MC/IOCACHE=y
- **Issue**: The EDAC drivers are custom AL code. They likely probe via
  known platform addresses but may need specific DT entries.
- **Resolution**: Can be added later; system boots without EDAC.

### 14. Fabric Interrupt Controller Details
- **Config**: CONFIG_AL_FIC=y, CONFIG_AL_SYSTEM_FABRIC=y, CONFIG_ALPINE_IOFIC=y
- **Issue**: These custom interrupt controllers aggregate interrupts from
  various SoC blocks. Their register addresses and interrupt routing are
  not visible in the upstream DTSI.
- **Resolution**: Needed for correct IRQ routing but may not be strictly
  required if using PCI-based interrupt discovery.

### 15. Micon V3 Protocol Details
- **Issue**: The micon_v3 driver communicates over UART1 at 115200 baud.
  Known commands: POW_OFF, REBOOT, BEEP 3. But the full command set
  (LED control, fan speed, temperature reporting, button events) is unknown.
- **Resolution**: Serial sniffing on UART1 during normal operation, or
  reverse engineering the micon firmware / Buffalo userspace tools.

### 16. SGPO (Serial GPIO) Controller
- **Address**: 0xfd8b4000 (PBS + 0x34000)
- **Issue**: The SDK defines AL_PBS_SGPO_BASE. This may be used for
  serial GPIO (shift-register based) LED/status outputs. No DT bindings known.
- **Resolution**: Check if any Buffalo platform code references SGPO.

### 17. DFX (Debug/Diagnostic) Block
- **Address**: 0xfd8e0000
- **Issue**: Present in SDK but purpose unclear. May be needed for SoC
  identification and eFuse reading.
- **Resolution**: Low priority; can be added when needed.

---

## Recommended Next Steps

1. **Highest value**: Dump the DTB from a running TS5020.
   - Via U-Boot: `fdt addr $fdtaddr; fdt print /`
   - Via Linux: `dtc -I dtb -O dts /sys/firmware/fdt`
   - This would resolve nearly ALL unknowns above.

2. **Second best**: Boot stock kernel with earlycon and capture full dmesg.
   - Reveals all probed devices, addresses, and IRQs.

3. **I2C scan**: Run `i2cdetect -y 0` (and other buses) on running system.
   - Maps out all I2C device addresses.

4. **PCI enumeration**: `lspci -vvv` on running system.
   - Shows all PCI devices with BARs and IRQs.

5. **GPIO exploration**: Check `/sys/class/gpio/` and `/sys/class/leds/` on
   running system for pin assignments.
