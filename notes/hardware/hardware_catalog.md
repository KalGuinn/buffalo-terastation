# Buffalo TS5020 Hardware Catalog

Derived from: buffalo_ts5020_defconfig, alpine-v2.dtsi, Annapurna Labs SDK patch,
and Buffalo platform patch.

## SoC: Annapurna Labs Alpine V2
- ARM64, quad Cortex-A57
- PCI Vendor ID: 0x1c36 (Annapurna Labs)
- Platform: `al,alpine-v2`
- Kernel config symbol: `CONFIG_ARCH_ALPINE=y`

## Register Map (SB_BASE = 0xfc000000, NB_BASE = 0xf0000000)

| Peripheral           | Base Address      | Notes                                      |
|----------------------|-------------------|--------------------------------------------|
| ETH0                 | 0xfc000000        | idx=0, offset = 0*0x100000                 |
| ETH1                 | 0xfc100000        | idx=1                                      |
| ETH2                 | 0xfc200000        | idx=2                                      |
| ETH3                 | 0xfc300000        | idx=3                                      |
| SSM/Crypto           | 0xfc600000        | idx=0, dev_num=6                           |
| SATA0                | 0xfc800000        | idx=0, dev_num=8                           |
| SATA1                | 0xfc900000        | idx=1, dev_num=9                           |
| PCIe (internal)      | 0xfd800000+       | 0x01800000 + idx*0x20000                   |
| PBS (platform bus)   | 0xfd880000        | I2C, SPI, UART, GPIO, WDT, Timer base     |
| I2C PLD              | 0xfd880000        | PBS + 0x00000                              |
| SPI Slave            | 0xfd881000        | PBS + 0x01000                              |
| SPI Master           | 0xfd882000        | PBS + 0x02000                              |
| UART0                | 0xfd883000        | PBS + 0x03000                              |
| UART1                | 0xfd884000        | PBS + 0x04000                              |
| UART2                | 0xfd885000        | PBS + 0x05000                              |
| UART3                | 0xfd886000        | PBS + 0x06000                              |
| GPIO0                | 0xfd890000        | PBS + offset varies by idx                 |
| Timer0               | 0xfd890000        | PBS + timer offset                         |
| WDT                  | PBS + WD offset   | arm,sp805                                  |
| I2C General          | 0xfd894000        | PBS + 0x14000                              |
| OTP                  | 0xfd896000        | PBS + 0x16000                              |
| SGPO                 | 0xfd8b4000        | PBS + 0x34000                              |
| SRAM                 | 0xfd8c0000        | PBS + 0x40000                              |
| Ring/PLL             | 0xfd860000        | SB + 0x01860000                            |
| DFX                  | 0xfd8e0000        | SB + 0x018e0000                            |
| TRNG                 | 0xfd9e0000        | SB + 0x019e0000                            |
| NB Service           | 0xf0070000        | NB + 0x70000                               |
| DDR Controller       | 0xf0080000        | NB + 0x80000                               |
| DDR PHY              | 0xf0088000        | NB + 0x88000                               |
| IOCache              | 0xf0098000        | NB + 0x98000                               |
| GIC Distributor      | 0xf0200000        | NB + 0x200000 (from DTSI)                  |
| GICR                 | 0xf0280000        | NB + 0x280000 (from DTSI)                  |
| PCI ECAM             | 0xfbc00000        | from DTSI                                  |
| MSI-X                | 0xfbe00000        | from DTSI                                  |

---

## Peripheral Catalog

### CPU / Core
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| Cortex-A57 x4 | CONFIG_SMP=y | arm,cortex-a57 | 4 cores |
| GICv3 | CONFIG_ARM_GIC_V3=y | arm,gic-v3 | In DTSI |
| ARMv8 Timer | CONFIG_ARM_ARCH_TIMER=y | arm,armv8-timer | In DTSI |
| PMU | n/a | arm,armv8-pmuv3 | In DTSI |
| PSCI | CONFIG_ARM_PSCI_FW=y | arm,psci-0.2 | In DTSI |
| ARM SMMU | CONFIG_ARM_SMMU=y | arm,mmu-500 (likely) | |

### Serial / UART
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| UART0 (console) | CONFIG_SERIAL_8250=y | ns16550a | 0xfd883000, SPI 17, 500MHz clk |
| UART1 (micon) | CONFIG_SERIAL_8250=y | ns16550a | 0xfd884000, SPI 18 - micon_v3 uses /dev/ttyS1 at 115200 |
| UART2 | CONFIG_SERIAL_8250=y | ns16550a | 0xfd885000, SPI 19 |
| UART3 | CONFIG_SERIAL_8250=y | ns16550a | 0xfd886000, SPI 20 |

### Storage
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| AHCI SATA | CONFIG_SATA_AHCI=y, CONFIG_AHCI_ALPINE=y | PCI device 1c36:0031 | On internal PCIe; SSS supported |
| SPI NOR (M25P80) | CONFIG_MTD_M25P80=y, CONFIG_MTD_SPI_NOR=y | jedec,spi-nor | Boot flash on SPI master |
| NAND | CONFIG_MTD_NAND_AL=y, CONFIG_MTD_NAND_DENALI_DT=y | annapurna-labs,al-nand (likely) | AL custom NAND controller |
| UBI/UBIFS | CONFIG_MTD_UBI=y, CONFIG_UBIFS_FS=y | | Over NAND |
| NVMe | CONFIG_BLK_DEV_NVME=y | | Over PCIe |
| MD RAID 0/1/5/6/10 | CONFIG_MD_RAID0/1/10/456=y | | Software RAID |
| DM-Crypt | CONFIG_DM_CRYPT=y | | Disk encryption |

### Networking
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| AL Ethernet | CONFIG_NET_AL_ETH=y, CONFIG_NET_AL_LM=y | (PCI-based, no DT compat) | Annapurna Labs native 10GbE |
| Realtek R8125 | CONFIG_R8125=y | (PCI device) | 2.5GbE PCIe NIC - out-of-tree driver |
| MACB | CONFIG_MACB=y | cdns,macb (likely) | Cadence GEM/MACB |
| Intel E1000E | CONFIG_E1000E=y | (PCI) | |
| Intel IGB | CONFIG_IGB=y | (PCI) | |
| Intel IXGBE | CONFIG_IXGBE=y | (PCI) | 10GbE |
| Aquantia PHY | CONFIG_AQUANTIA_PHY=y | | |
| MaxLinear GPHY | CONFIG_MAXLINEAR_GPHY=y | | |
| Realtek PHY | CONFIG_REALTEK_PHY=y | | |
| Micrel PHY | CONFIG_MICREL_PHY=y | | |
| SMC91x | CONFIG_SMC91X=y | smsc,lan91c111 (likely) | |
| SMSC911x | CONFIG_SMSC911X=y | smsc,lan9220 (likely) | |
| MDIO bitbang | CONFIG_MDIO_BITBANG=y | | |
| MDIO mux mmioreg | CONFIG_MDIO_BUS_MUX_MMIOREG=y | | |

### I2C
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| DesignWare I2C | CONFIG_I2C_DESIGNWARE_PLATFORM=y | snps,designware-i2c | PBS I2C controller |
| I2C MUX PCA954x | CONFIG_I2C_MUX_PCA954x=y | nxp,pca9548 (likely) | I2C bus multiplexer |
| EEPROM AT24 | CONFIG_EEPROM_AT24=y | atmel,24c* | Board config EEPROM |
| LM75 temp sensor | CONFIG_SENSORS_LM75=y | national,lm75 | Temperature sensor |
| RTC RX8010 | CONFIG_RTC_DRV_RX8010=y | epson,rx8010 | Primary RTC (per README) |
| RTC DS1307 | CONFIG_RTC_DRV_DS1307=y | dallas,ds1307 | |
| TPM I2C Infineon | CONFIG_TCG_TIS_I2C_INFINEON=y | infineon,slb9635tt | Security chip |
| GPIO PCA953x | CONFIG_GPIO_PCA953X=y | nxp,pca9555 (likely) | I2C GPIO expander with IRQ |
| INA2xx | CONFIG_SENSORS_INA2XX=m | ti,ina220 (likely) | Current/power monitor |
| LM90 | CONFIG_SENSORS_LM90=m | national,lm90 | Temperature sensor |

### SPI
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| DesignWare SPI | CONFIG_SPI_DESIGNWARE=y, CONFIG_SPI_DW_MMIO=y | snps,dw-apb-ssi | PBS SPI master |
| PL022 SPI | CONFIG_SPI_PL022=y | arm,pl022 | AMBA SPI |
| EEPROM AT25 | CONFIG_EEPROM_AT25=m | | SPI EEPROM |

### GPIO
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| DWAPB GPIO | CONFIG_GPIO_DWAPB=y | snps,dw-apb-gpio | Main SoC GPIO |
| PL061 GPIO | CONFIG_GPIO_PL061=y | arm,pl061 | |
| GPIO keys | CONFIG_KEYBOARD_GPIO=y | gpio-keys | Power button etc. |
| GPIO LEDs | CONFIG_LEDS_GPIO=y | gpio-leds | Status/disk LEDs |

### Timers / Watchdog
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| SP804 Timer | CONFIG_ARM_TIMER_SP804=y | arm,sp804 | In DTSI, 4 timers |
| SP805 Watchdog | CONFIG_ARM_SP805_WATCHDOG=y | arm,sp805 | |

### DMA
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| AL SSM PCIe | CONFIG_AL_SSM_PCIE=y | | Crypto/RAID DMA engine |
| AL DMA | CONFIG_AL_DMA=m | | DMA engine with VF support |
| PL330 DMA | CONFIG_PL330_DMA=y | arm,pl330 | |
| MV XOR V2 | CONFIG_MV_XOR_V2=y | marvell,mvebu-dma | |

### USB
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| xHCI (USB 3.0) | CONFIG_USB_XHCI_HCD=y, CONFIG_USB_XHCI_PLATFORM=y | generic-xhci | |
| EHCI (USB 2.0) | CONFIG_USB_EHCI_HCD=y, CONFIG_USB_EHCI_HCD_PLATFORM=y | generic-ehci | |
| OHCI | CONFIG_USB_OHCI_HCD=y | generic-ohci | |
| DWC3 | CONFIG_USB_DWC3=y, CONFIG_USB_DWC3_OF_SIMPLE=y | snps,dwc3 | USB3 DRD |
| DWC2 | CONFIG_USB_DWC2=y | snps,dwc2 | USB2 OTG |
| USB Serial PL2303 | CONFIG_USB_SERIAL_PL2303=y | | Prolific USB-Serial |
| USB3503 HSIC | CONFIG_USB_HSIC_USB3503=y | smsc,usb3503 | USB hub |

### PCIe
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| ECAM generic | CONFIG_PCI_HOST_GENERIC=y | pci-host-ecam-generic | In DTSI |
| AL internal PCIe | CONFIG_PCI_INTERNAL_ALPINE=y | | Custom AL PCIe driver |
| AL external PCIe | CONFIG_PCI_EXTERNAL_ALPINE=y | | Custom AL PCIe driver |
| MSI-X | CONFIG_ALPINE_MSI=y | al,alpine-msix | In DTSI |

### Interrupt Controllers
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| AL FIC | CONFIG_AL_FIC=y | amazon,al-fic | Fabric Interrupt Controller |
| AL System Fabric | CONFIG_AL_SYSTEM_FABRIC=y | | System fabric IRQ |
| AL System Error | CONFIG_AL_SYSTEM_ERROR=y | | System error IRQ |
| Alpine IOFIC | CONFIG_ALPINE_IOFIC=y | | IO fabric IRQ |

### Thermal
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| AL Thermal V2 | CONFIG_AL_THERMAL_V2=y | | Alpine V2 thermal sensor |
| AL Thermal V3 | CONFIG_AL_THERMAL_V3=y | | Alpine V3 thermal sensor |
| Thermal MMIO | CONFIG_THERMAL_MMIO=y | | |

### EDAC (Error Detection)
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| AL L1 EDAC | CONFIG_EDAC_AL_L1=y | | L1 cache ECC |
| AL L2 EDAC | CONFIG_EDAC_AL_L2=y | | L2 cache ECC |
| AL MC EDAC | CONFIG_EDAC_AL_MC=y | | Memory controller ECC |
| AL IOCache EDAC | CONFIG_EDAC_AL_IOCACHE=y | | IO cache ECC |

### Power Management
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| Alpine Reboot | CONFIG_POWER_RESET_ALPINE=y | | Custom reboot driver |
| SYSCON Reboot | CONFIG_POWER_RESET_SYSCON=y | syscon-reboot | |

### MMC/SD
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| SDHCI ARASAN | CONFIG_MMC_SDHCI_OF_ARASAN=y | arasan,sdhci-8.9a | |
| MMC DW | CONFIG_MMC_DW=y | snps,dw-mshc | DesignWare MMC |
| MMC SPI | CONFIG_MMC_SPI=y | | |
| ARM MMCI | CONFIG_MMC_ARMMMCI=y | arm,pl18x | |

### Clocks
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| Fixed clock (sbclk) | | fixed-clock | 1MHz, in DTSI |
| SP810 | CONFIG_CLK_SP810=y | arm,sp810 | |
| SCPI clock | CONFIG_COMMON_CLK_SCPI=y | | |

### Mailbox
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| ARM MHU | CONFIG_ARM_MHU=y | arm,mhu | |
| Platform MHU | CONFIG_PLATFORM_MHU=y | | |

### Security
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| OP-TEE | CONFIG_OPTEE=y | linaro,optee-tz | Trusted Execution |

### SOC-specific
| Feature | Config | Compatible | Notes |
|---------|--------|------------|-------|
| AL HAL | CONFIG_AL_HAL=y | | Annapurna Labs Hardware Abstraction Layer |
| AL POS | CONFIG_AL_POS=y | | PCIe ordering service |
| AL PCIe unit adapter | CONFIG_AL_PCIE_UNIT_ADAPTER=y | | |
| Platform: ALPINE_V2 | CONFIG_ALPINE_PLATFORM="ALPINE_V2" | | |

### Buffalo-specific
| Feature | Config | Notes |
|---------|--------|-------|
| Buffalo Platform | CONFIG_BUFFALO_PLATFORM=y | Core platform support |
| Micon V3 | CONFIG_BUFFALO_MICON_REBOOT=y | Microcontroller on UART1 (/dev/ttyS1) at 115200 baud |
| Buffalo RAID events | CONFIG_BUFFALO_USE_MD_KERNEVNT=y | MD RAID kernel events |
| Buffalo UPS | CONFIG_BUFFALO_USE_UPS=y | UPS monitoring |
| Buffalo IO errors | CONFIG_BUFFALO_IOERRS=y | IO error tracking |
| Alpine V2 Platform | CONFIG_BUFFALO_ALPINE_V2_PLATFORM=y | Creates /sys/class/ts5020 |
| Board info | CONFIG_BUFFALO_SUPPORT_BOARD_INFO=y | Board identification |
