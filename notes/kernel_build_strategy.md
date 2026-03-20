# Modern Kernel Build Strategy: Buffalo TS51220RH (Alpine V2)

Target: Run a modern mainline Linux kernel on a Buffalo TeraStation TS51220RH
SoC: Annapurna Labs Alpine V2 (quad Cortex-A57, ARM64)
Base: Buffalo GPL source = Linux 4.19.75 + AL SDK patch (384 files) + Buffalo patch (141 files)
Date: 2026-03-19

---

## 1. Target Kernel Version

**Recommended: Linux 6.12.x LTS** (or latest 6.x LTS available)

Rationale:
- LTS branch ensures stability and extended support
- Alpine V2 basic platform support (ARCH_ALPINE, GICv3, timer, PSCI) has been
  in mainline since ~4.8 (arm64) and continuously maintained
- The `arch/arm64/boot/dts/amazon/` directory (renamed from `al/` around v5.7)
  contains Alpine devicetrees in mainline
- A 6.12 LTS gives us the most mature state of already-upstreamed AL drivers

**Note:** Unable to verify exact latest stable from kernel.org due to web search
restrictions. As of the model's knowledge (May 2025), 6.12 was the latest LTS.
Check https://kernel.org before starting.

---

## 2. Mainline Alpine V2 Support Assessment

### What IS in modern mainline kernels

| Component | Status | Mainline Location | Notes |
|-----------|--------|-------------------|-------|
| ARCH_ALPINE platform | Upstream | `arch/arm64/Kconfig.platforms` | Since ~4.8 |
| GICv3 | Upstream | `drivers/irqchip/irq-gic-v3.c` | Standard ARM |
| ARMv8 timer | Upstream | Standard ARM | Standard ARM |
| PSCI | Upstream | Standard ARM | Standard ARM |
| Alpine MSI | Upstream | `drivers/irqchip/irq-alpine-msi.c` | Since ~4.8 |
| Alpine FIC | Upstream | `drivers/irqchip/irq-al-fic.c` | Merged ~5.2 |
| PCIe (pcie-al.c) | Upstream | `drivers/pci/controller/dwc/pcie-al.c` | DesignWare-based, merged ~5.4 |
| AHCI Alpine | Partially upstream | `drivers/ata/ahci.c` | Basic Alpine AHCI ID in mainline |
| DesignWare I2C | Upstream | `drivers/i2c/busses/i2c-designware-*` | Standard IP |
| DesignWare SPI | Upstream | `drivers/spi/spi-dw-*` | Standard IP |
| DesignWare GPIO | Upstream | `drivers/gpio/gpio-dwapb.c` | Standard IP |
| SP805 Watchdog | Upstream | `drivers/watchdog/sp805_wdt.c` | Standard ARM IP |
| SP804 Timer | Upstream | `drivers/clocksource/timer-sp804.c` | Standard ARM IP |
| PL011 UART | Upstream | `drivers/tty/serial/amba-pl011.c` | Standard ARM IP |
| 8250/ns16550a UART | Upstream | `drivers/tty/serial/8250/` | Standard |
| PL061 GPIO | Upstream | `drivers/gpio/gpio-pl061.c` | Standard ARM IP |
| PL330 DMA | Upstream | `drivers/dma/pl330.c` | Standard ARM IP |
| Denali NAND | Upstream | `drivers/mtd/nand/raw/denali_dt.c` | Standard IP |
| DWC3 USB3 | Upstream | `drivers/usb/dwc3/` | Standard IP |
| DWC2 USB2 | Upstream | `drivers/usb/dwc2/` | Standard IP |
| xHCI/EHCI/OHCI | Upstream | Standard USB HCDs | Standard |
| Alpine reboot | Upstream | `drivers/power/reset/alpine-poweroff.c` | Since ~4.13 |
| RTC RX8010 | Upstream | `drivers/rtc/rtc-rx8010.c` | Standard I2C RTC |
| RTC DS1307 | Upstream | `drivers/rtc/rtc-ds1307.c` | Standard I2C RTC |
| LM75 temp sensor | Upstream | `drivers/hwmon/lm75.c` | Standard I2C hwmon |
| AT24 EEPROM | Upstream | `drivers/misc/eeprom/at24.c` | Standard I2C |
| PCA954x I2C mux | Upstream | `drivers/i2c/muxes/i2c-mux-pca954x.c` | Standard I2C |
| PCA953x GPIO exp | Upstream | `drivers/gpio/gpio-pca953x.c` | Standard I2C |
| SDHCI Arasan | Upstream | `drivers/mmc/host/sdhci-of-arasan.c` | Standard IP |
| DW MMC | Upstream | `drivers/mmc/host/dw_mmc.c` | Standard IP |
| Aquantia PHY | Upstream | `drivers/net/phy/aquantia/` | Standard PHY |
| Realtek PHY | Upstream | `drivers/net/phy/realtek.c` | Standard PHY |
| Micrel PHY | Upstream | `drivers/net/phy/micrel.c` | Standard PHY |
| Marvell PHY | Upstream | `drivers/net/phy/marvell.c` | Standard PHY |
| GPIO LEDs | Upstream | `drivers/leds/leds-gpio.c` | Standard |
| GPIO keys | Upstream | `drivers/input/keyboard/gpio_keys.c` | Standard |
| Devicetree base | Upstream | `arch/arm64/boot/dts/amazon/` | alpine-v2.dtsi exists |

### What is NOT in mainline (from AL SDK patch)

| Component | Config | SDK Patch Files | Difficulty |
|-----------|--------|-----------------|------------|
| **AL Ethernet driver** | `CONFIG_NET_AL_ETH`, `CONFIG_NET_AL_LM` | `drivers/net/ethernet/al/` (~250+ files in HAL) | **HARD** |
| AL HAL (hardware abstraction) | `CONFIG_AL_HAL` | `drivers/soc/alpine/HAL/` (massive) | **HARD** - dependency for many drivers |
| AL Thermal V2/V3 | `CONFIG_AL_THERMAL_V2/V3` | `drivers/thermal/` (AL-specific) | MEDIUM |
| AL DMA engine | `CONFIG_AL_DMA` | `drivers/dma/al/` | MEDIUM |
| AL SSM (crypto/RAID accel) | `CONFIG_AL_SSM_PCIE` | `drivers/crypto/` or `drivers/dma/` | MEDIUM |
| AL NAND controller | `CONFIG_MTD_NAND_AL` | `drivers/mtd/nand/raw/` (AL-specific) | MEDIUM |
| AL System Fabric IRQ | `CONFIG_AL_SYSTEM_FABRIC` | `drivers/irqchip/irq-al-system-fabric.c` | LOW-MEDIUM |
| AL System Error | `CONFIG_AL_SYSTEM_ERROR` | Part of fabric IRQ handling | LOW |
| Alpine IOFIC | `CONFIG_ALPINE_IOFIC` | IO fabric interrupt controller | LOW-MEDIUM |
| AL POS (Position) | `CONFIG_AL_POS` | `drivers/soc/amazon/al_pos.c` | LOW |
| AL PCIe internal/external | `CONFIG_PCI_INTERNAL/EXTERNAL_ALPINE` | Extensions to PCIe controller | MEDIUM |
| AL PCIe unit adapter | `CONFIG_AL_PCIE_UNIT_ADAPTER` | PCIe hot-plug/error handling | MEDIUM |
| AL L1/L2/MC/IOCache EDAC | `CONFIG_EDAC_AL_*` | `drivers/edac/al_*_edac.c` | LOW |
| IRQ Event Handler | `CONFIG_IRQ_EVENT_HANDLER` | `drivers/misc/irq-event-handler.c` | LOW |
| Realtek R8125 driver | `CONFIG_R8125` | Out-of-tree Realtek driver | LOW (upstream r8169 may work) |
| AHCI Alpine SSS | `CONFIG_AHCI_ALPINE_SSS` | AHCI staggered spinup extension | LOW |
| AL DDR Patrol | `CONFIG_AL_DDR_PATROL` | DDR patrol scrubbing | LOW (disabled in defconfig) |

---

## 3. Driver Classification

### a) Already Upstream -- No porting needed

These work out of the box with a modern kernel and the correct devicetree:

- **ARCH_ALPINE platform** (core SoC support)
- **GICv3 interrupt controller**
- **ARMv8 generic timer**
- **PSCI CPU management**
- **Alpine MSI** (PCI MSI-X)
- **AL FIC** (Fabric Interrupt Controller) -- merged upstream
- **PCIe controller** (pcie-al.c, DesignWare-based) -- merged upstream
- **Basic AHCI SATA** (Alpine PCI device ID 1c36:0031 recognized by mainline ahci.c)
- **All DesignWare IP**: I2C, SPI, GPIO (DWAPB), UART (8250-dw)
- **All ARM PrimeCell IP**: PL011, PL061, SP805 WDT, SP804 timer, PL330 DMA, PL022 SPI
- **All standard I2C peripherals**: RX8010 RTC, DS1307 RTC, LM75, AT24 EEPROM, PCA954x mux, PCA953x GPIO, INA2xx, LM90, TPM Infineon
- **USB**: DWC3, DWC2, xHCI, EHCI, OHCI
- **Storage**: Denali NAND (DT), SPI NOR (M25P80/jedec,spi-nor), NVMe, MD RAID, DM
- **Network PHYs**: Aquantia, Realtek, Micrel, Marvell, MaxLinear
- **Standard PCI NICs**: E1000E, IGB, IXGBE (Intel NICs on PCIe)
- **MMC/SD**: SDHCI Arasan, DW MMC
- **Misc**: GPIO LEDs, GPIO keys, Alpine reboot/poweroff

### b) Needs Porting -- Out-of-tree drivers requiring forward-port

These are AL SDK drivers with no mainline equivalent. Must be forward-ported from 4.19 to target kernel:

1. **AL Ethernet (al_eth) + AL HAL** -- The primary network interface
   - ~250+ source files in `drivers/net/ethernet/al/`
   - Depends on massive AL HAL layer (`drivers/soc/alpine/HAL/`)
   - This is the SINGLE HARDEST component to port
   - The HAL is a register-level abstraction covering ETH, DMA, SerDes, UDMA
   - Amazon never upstreamed this driver (they use ENA in AWS, not al_eth)

2. **AL Thermal V2/V3** -- SoC thermal monitoring
   - Custom thermal zone driver for Alpine thermal sensors
   - Needed for thermal management / fan control
   - Moderate porting effort, self-contained

3. **AL DMA engine** -- Hardware DMA with PCI SR-IOV
   - Custom DMA engine driver
   - Used for data movement acceleration
   - Moderate effort, depends on AL HAL

4. **AL SSM (Security/Storage Manager)** -- Crypto + RAID acceleration
   - Hardware crypto and XOR/RAID acceleration engine
   - Nice-to-have for RAID performance, not boot-critical
   - Moderate effort, depends on AL HAL

5. **AL NAND controller** -- Custom NAND flash controller
   - May overlap with Denali NAND (check if Denali covers this HW)
   - Needed if boot flash uses NAND (SPI NOR is separate)
   - Moderate effort

### c) Can Be Dropped -- Vendor/Buffalo-specific, not needed

1. **All BUFFALO_* configs** -- Buffalo NAS application layer
   - `CONFIG_BUFFALO_PLATFORM`, `CONFIG_BUFFALO_USE_KERNEVNT`, etc.
   - BUFFALO_USE_MD_KERNEVNT (RAID event notifications to userspace)
   - BUFFALO_ERRCNT (error counting)
   - BUFFALO_USE_UPS (UPS integration)
   - BUFFALO_IOERRS, BUFFALO_SKIP_RESYNC
   - BUFFALO_IGNORE_LUN, BUFFALO_SCSI_GUID
   - BUFFALO_EXT23_EXTENSION
   - BUFFALO_ALPINE_V2_PLATFORM (sysfs board info)
   - micon_v3 driver (microcontroller communication) -- could be reimplemented in userspace
   - Buffalo kernel event system -- replaced by standard Linux mechanisms

2. **Buffalo's iSCSI target modifications** -- Heavy modifications to LIO/iSCSI target
   - 20+ files in `drivers/target/` modified
   - These are Buffalo-specific iSCSI extensions
   - Use standard mainline LIO if iSCSI target is needed

3. **Buffalo's CIFS/btrfs patches** -- Backports and vendor fixes
   - 15+ files in `fs/cifs/`, 15+ files in `fs/btrfs/`
   - These were backports/fixes for 4.19; modern kernels have them already

4. **Buffalo's SCSI patches** -- SCSI subsystem modifications
   - Custom SCSI quirks and error handling
   - Standard mainline SCSI is fine

5. **AL DDR Patrol** -- Already disabled in defconfig

6. **IRQ Event Handler** -- Generic IRQ logging utility, non-essential

7. **skip_serror_panic** -- Hack in `arch/arm64/kernel/traps.c` to suppress SErrors
   - Dangerous; should not be carried forward

### d) Has Upstream Alternative -- Vendor driver replaceable

1. **Realtek R8125 (2.5GbE)** -- Out-of-tree Realtek driver
   - **Alternative**: Mainline `r8169` driver gained R8125/RTL8125 support in ~5.9+
   - Should work with mainline r8169, test and verify
   - If not, Realtek provides an updated out-of-tree driver that's easy to compile

2. **AL PCIe internal/external** -- Custom PCIe controller extensions
   - **Alternative**: Mainline `pcie-al.c` (DesignWare-based) should handle basic PCIe
   - The SDK adds error handling, hot-plug, internal bus enumeration
   - Basic PCIe should work; advanced features may need porting

3. **AHCI Alpine SSS** -- Staggered Spin-up Support
   - **Alternative**: Mainline AHCI handles this in some form
   - SSS reduces inrush current when spinning up 12 disks simultaneously
   - May need a small patch to enable if not in mainline AHCI

4. **AL EDAC drivers** (L1, L2, MC, IOCache)
   - **Alternative**: Mainline GHES EDAC may provide basic ECC reporting via ACPI
   - AL-specific EDAC gives finer-grained reporting
   - Not boot-critical; can be ported later as modules

5. **MV XOR V2** (DMA for RAID parity)
   - **Alternative**: In mainline as `drivers/dma/mv_xor_v2.c`
   - Should work out of the box

---

## 4. Minimum Viable Kernel (MVK)

Goal: Boot to shell + SATA + Ethernet + I2C

### Required for boot to shell on UART0:
- `ARCH_ALPINE=y`
- GICv3 (`ARM_GIC_V3=y`)
- ARMv8 timer
- PSCI
- Serial 8250 + 8250_DW (ns16550a UARTs at 0xfd883000)
- Devicetree (our extracted + fixed DTS)
- initramfs or root on SATA/NVMe/USB

### Required for SATA (disk access):
- `SATA_AHCI=y`, `SATA_AHCI_PLATFORM=y`
- `AHCI_ALPINE=y` (if mainline has the Alpine AHCI platform bits)
- PCIe support (SATA is on internal PCIe): `PCI=y`, DesignWare PCIe, `pcie-al.c`
- Alpine MSI (`ALPINE_MSI=y`)
- `BLK_DEV_SD=y` (SCSI disk)
- `EXT4_FS=y` or `XFS_FS=y` (filesystem)

### Required for Ethernet (at least one port):
- **Option A**: Use a PCI NIC (Intel IGB/E1000E) if one is present on PCIe
  - This avoids the massive al_eth porting effort
  - `IGB=y` or `E1000E=y` -- standard mainline drivers
- **Option B**: Port the AL Ethernet driver
  - Required if no other NIC is available
  - This is the hard path but may be necessary for the native 10GbE ports

### Required for I2C:
- `I2C_DESIGNWARE_PLATFORM=y` (DesignWare I2C controller)
- `I2C_MUX_PCA954x=y` (I2C mux)
- `RTC_DRV_RX8010=y` (hardware RTC)
- `SENSORS_LM75=y` (temperature)

### MVK Config Strategy:
Start with `defconfig` for arm64 (generic), then enable:
```
CONFIG_ARCH_ALPINE=y        # (disable all other platforms)
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_DW=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_SATA_AHCI=y
CONFIG_SATA_AHCI_PLATFORM=y
CONFIG_PCI=y
CONFIG_PCIE_DW_HOST=y
CONFIG_BLK_DEV_SD=y
CONFIG_I2C_DESIGNWARE_PLATFORM=y
CONFIG_I2C_MUX_PCA954x=y
CONFIG_RTC_DRV_RX8010=y
CONFIG_SENSORS_LM75=y
CONFIG_GPIO_DWAPB=y
CONFIG_GPIO_PCA953X=y
CONFIG_ARM_SP805_WATCHDOG=y
CONFIG_EXT4_FS=y
CONFIG_XFS_FS=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
```

---

## 5. Risks and Unknowns

### HIGH RISK

1. **AL Ethernet driver porting**
   - The #1 risk. The AL HAL is enormous (~250+ files), tightly coupled, and uses
     its own abstraction over register access, DMA, SerDes configuration, and more.
   - API changes between 4.19 and 6.x in NAPI, netdev, DMA mapping, and SKB
     allocation will require significant rework.
   - The driver was never upstreamed by Amazon because they pivoted to ENA for
     AWS Nitro. There is no community maintainer.
   - **Mitigation**: Phase 1 can use an Intel PCI NIC if one is installed.
     The native AL ethernet can be tackled in Phase 2.

2. **U-Boot compatibility with modern kernel**
   - The existing U-Boot expects a specific DTB format and kernel image format
   - Modern kernels produce Image (uncompressed) or Image.gz
   - U-Boot on this device likely expects `uImage` (see .gitignore adding `uImage`)
   - U-Boot may pass an embedded DTB or expect one appended
   - **Risk**: If U-Boot is too old, it may not support `booti` (ARM64 Image boot)
     and may only support `bootm` (uImage)
   - **Mitigation**: Use `mkimage` to wrap the kernel as a uImage, or use
     U-Boot's `booti` command if available. The DTB should be passed separately.
   - **Risk**: U-Boot may enforce secure boot / signed kernel images
   - **Mitigation**: Check if Buffalo's U-Boot verifies signatures. If so,
     need to find a way to disable or use the signing key.

3. **DTB compatibility**
   - Our extracted DTB was designed for the 4.19 kernel with AL SDK patches
   - It references custom compatible strings and bindings that may not exist
     in mainline (e.g., AL-specific ethernet, thermal, NAND nodes)
   - **Mitigation**: Start with the extracted DTS, comment out nodes for
     unavailable drivers, and iteratively fix. The mainline `alpine-v2.dtsi`
     can be used as a reference for standard nodes.

### MEDIUM RISK

4. **PCIe enumeration for SATA**
   - SATA controllers are behind internal PCIe on this SoC
   - Mainline `pcie-al.c` should handle this, but the SDK patch adds significant
     internal PCIe bus management code
   - If mainline PCIe doesn't enumerate the internal SATA controllers, we have
     no disk access
   - **Mitigation**: The mainline pcie-al.c was tested on Alpine hardware by
     Amazon engineers. Internal PCIe for AHCI should work.

5. **SerDes configuration**
   - The AL HAL includes SerDes (serializer/deserializer) initialization
   - SerDes configures whether physical lanes are used for PCIe, SATA, or Ethernet
   - U-Boot typically handles SerDes init before kernel boot
   - **Risk**: If the kernel needs to reinitialize SerDes (e.g., for lane
     reconfiguration), we need the AL HAL
   - **Mitigation**: Rely on U-Boot to set up SerDes. Don't change lane config.

6. **Thermal management without AL thermal driver**
   - Without AL_THERMAL_V2, the kernel won't read SoC temperature
   - Risk of thermal throttling not engaging, potential CPU damage under load
   - **Mitigation**: External I2C temperature sensors (LM75) still work for
     ambient monitoring. Port the thermal driver in Phase 2.

### LOW RISK

7. **Binary blobs / firmware files**
   - No evidence of required binary firmware blobs for core functionality
   - The PHY drivers (Aquantia) may need firmware files, but these are
     available in linux-firmware
   - WiFi/BT modules need firmware but are not critical for NAS operation
   - **Assessment**: No showstopper binary blob issues expected

8. **I2C peripheral access**
   - All I2C peripherals use standard upstream drivers
   - The I2C controller (DesignWare) is well-supported in mainline
   - Low risk

9. **Fan control**
   - Buffalo uses micon_v3 (microcontroller on UART1) for fan/LED control
   - Without this, fans may run at full speed (fail-safe) or not at all
   - **Mitigation**: Reimplement micon protocol in userspace using /dev/ttyS1.
     The protocol is likely simple serial commands.

---

## 6. Phased Build Plan

### Phase 1: Minimal Boot (Console + Storage)

**Goal**: Boot a modern kernel, get a shell on UART0, mount SATA disks.

**Duration estimate**: 1-2 weeks

**Steps**:
1. Download and extract target kernel source (6.12 LTS or latest stable)
2. Set up cross-compilation environment (see Section 7)
3. Create a minimal defconfig based on arm64 defconfig:
   - Enable only ARCH_ALPINE, disable all other platforms
   - Enable 8250 serial, AHCI, PCIe, basic I2C
   - Build with initramfs containing busybox
4. Adapt our extracted DTS for mainline:
   - Start from mainline `alpine-v2.dtsi` as include
   - Add our board-specific nodes (UARTs, I2C topology, SATA)
   - Comment out nodes for unavailable drivers (AL ethernet, thermal, etc.)
   - Compile with mainline `dtc`
5. Build: `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image dtbs`
6. Package for U-Boot:
   - Create uImage if needed: `mkimage -A arm64 -T kernel -C none -a 0x80000 -e 0x80000 -d Image uImage`
   - Or use `booti` if U-Boot supports it
7. Boot test via TFTP + UART console:
   - Load kernel and DTB via TFTP in U-Boot
   - `tftpboot 0x80000 Image; tftpboot 0x8000000 alpine-v2-ts5020.dtb; booti 0x80000 - 0x8000000`
8. Debug boot issues:
   - Enable earlycon: `earlycon=uart8250,mmio32,0xfd883000,115200n8`
   - Check if GIC, timer, and serial come up
   - Check PCIe enumeration and SATA detection

**Success criteria**: Shell prompt on UART0, `lsblk` shows SATA disks.

### Phase 2: Full Hardware Support

**Goal**: Working ethernet, all I2C peripherals, thermal, fan control.

**Duration estimate**: 3-6 weeks (ethernet is the bottleneck)

**Steps**:
1. **Ethernet (choose one path)**:
   - **Path A (easy)**: Install an Intel IGB/IXGBE PCIe NIC. Zero porting effort.
     Good for development and testing. May be permanent solution if acceptable.
   - **Path B (hard)**: Forward-port the AL Ethernet driver + AL HAL from 4.19 to 6.x:
     a. Extract the AL HAL source from the SDK patch
     b. Create an out-of-tree module build system
     c. Fix API changes: `napi_gro_receive()`, `netdev_alloc_skb()`, DMA API,
        `struct net_device_ops`, PHYLIB/PHYLINK migration
     d. Test with one port first, then all four
     e. SerDes init: verify U-Boot has configured the Ethernet SerDes lanes

2. **I2C peripherals** (should mostly just work):
   - Enable all I2C drivers in config
   - Verify RTC, temperature sensors, EEPROM, GPIO expanders on I2C bus
   - Test with `i2cdetect`, `hwmon` sysfs

3. **AL Thermal driver**:
   - Forward-port `al_thermal_v2.c` from SDK patch
   - Register as standard thermal zone
   - Moderate effort, self-contained driver

4. **Micon (microcontroller) communication**:
   - Write userspace daemon to talk to micon_v3 on /dev/ttyS1
   - Control: fan speed, LEDs, buzzer, power button, LCD (if present)
   - Alternative: port micon_v3 kernel driver (simpler but less flexible)

5. **EDAC** (optional):
   - Forward-port AL EDAC drivers for ECC reporting
   - Low priority, nice-to-have for production

6. **NAND flash** (if needed):
   - Test if mainline Denali NAND handles the AL NAND controller
   - If not, port AL NAND driver
   - Only needed if accessing NAND-based storage (boot flash is SPI NOR)

**Success criteria**: All four Ethernet ports working (native or via PCI NIC),
`sensors` shows temperatures, NTP syncs via hardware RTC.

### Phase 3: Optimization and Cleanup

**Goal**: Production-ready kernel, performance tuning, upstreaming.

**Duration estimate**: 2-4 weeks

**Steps**:
1. **DMA acceleration**:
   - Port AL DMA engine for data movement acceleration
   - Port AL SSM for hardware RAID parity / crypto acceleration
   - Benchmark RAID rebuild with/without hardware acceleration

2. **Performance tuning**:
   - Tune kernel config: remove unnecessary drivers, optimize for ARM64
   - Enable RAID-specific optimizations
   - Configure CPU frequency scaling (CPUFREQ_DT should work)
   - Tune network: RSS, IRQ affinity, ring buffers

3. **Devicetree cleanup**:
   - Ensure DTS follows mainline bindings
   - Submit DTS upstream to `arch/arm64/boot/dts/amazon/`
   - Document all board-specific nodes

4. **Module build system**:
   - Create DKMS packages for out-of-tree drivers (AL ethernet, thermal)
   - Build system for easy kernel updates

5. **Testing**:
   - Stress test: bonnie++, iperf3, mdadm rebuild under load
   - Thermal test: verify throttling works
   - Power cycle test: verify clean shutdown/reboot via micon
   - Long-running stability test (72+ hours)

---

## 7. Cross-Compilation Toolchain on macOS

### Option A: Homebrew cross-compiler (Recommended for quick iteration)

```bash
# Install aarch64 cross-compiler
brew install aarch64-elf-gcc

# This provides aarch64-elf-gcc, but Linux kernel needs aarch64-linux-gnu-*
# Homebrew may not have the full Linux-targeting toolchain.
# Check:
brew search aarch64
```

**Problem**: Homebrew's `aarch64-elf-gcc` targets bare-metal ELF, not Linux.
The kernel needs `aarch64-linux-gnu-gcc` which targets Linux ABI. This
distinction matters for kernel builds (different ABI, different header paths).

### Option B: Docker with Linux cross-compiler (Recommended for correctness)

```bash
# Create a Dockerfile for kernel building
cat > Dockerfile.kernel-build << 'DOCKERFILE'
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    bc \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    device-tree-compiler \
    u-boot-tools \
    cpio \
    kmod \
    rsync \
    python3 \
    && rm -rf /var/lib/apt/lists/*

ENV ARCH=arm64
ENV CROSS_COMPILE=aarch64-linux-gnu-

WORKDIR /kernel
DOCKERFILE

# Build the Docker image
docker build -t kernel-build -f Dockerfile.kernel-build .

# Run kernel build (mount source tree)
docker run --rm -v $(pwd)/kernel:/kernel kernel-build \
    make defconfig
docker run --rm -v $(pwd)/kernel:/kernel kernel-build \
    make -j$(nproc) Image dtbs modules
```

### Option C: OrbStack / Lima (lightweight Linux VM on macOS)

```bash
# Using OrbStack (fast Docker alternative for macOS)
brew install orbstack

# Or Lima (lightweight Linux VMs)
brew install lima
limactl start default

# Then install cross-compiler inside the Linux VM
lima sudo apt install gcc-aarch64-linux-gnu
```

### Option D: Cross-compile natively on Apple Silicon

Since the Mac itself is ARM64, we can potentially use a native aarch64
compiler if we're building for the same architecture. However, macOS and
Linux have different system call ABIs, so we still need a Linux-targeting
cross-compiler. The Docker approach is most reliable.

### Recommended Setup

```bash
# 1. Install Docker Desktop or OrbStack
brew install --cask orbstack   # or docker

# 2. Create build container
docker build -t kernel-build -f Dockerfile.kernel-build .

# 3. Create a convenience script
cat > build.sh << 'SCRIPT'
#!/bin/bash
docker run --rm \
    -v "$(pwd)/kernel:/kernel" \
    -v "$(pwd)/devicetree:/devicetree" \
    -e ARCH=arm64 \
    -e CROSS_COMPILE=aarch64-linux-gnu- \
    kernel-build \
    "$@"
SCRIPT
chmod +x build.sh

# 4. Usage
./build.sh make defconfig
./build.sh make -j8 Image dtbs
```

### Required tools outside the kernel build:
```bash
# On macOS, for DTS editing and firmware work
brew install dtc           # device tree compiler
brew install binwalk        # firmware analysis
brew install u-boot-tools   # mkimage
brew install minicom        # serial console
brew install tftpd-hpa      # TFTP server for network boot (or use macOS built-in)
```

---

## 8. Quick Reference: File Locations

| What | Where |
|------|-------|
| Extracted DTB/DTS | `devicetree/` |
| AL SDK patch | `gpl-source/v4.19.75-241-g0fb91c28a25c.patch` |
| Buffalo patch | `gpl-source/linux-4.19.75_buffalo.patch` |
| Defconfig | `research/buffalo_ts5020_defconfig-snippet.txt` |
| Hardware catalog | `notes/hardware_catalog.md` |
| This document | `notes/kernel_build_strategy.md` |
| Kernel source (to create) | `kernel/` |

---

## 9. Summary: Effort Estimate

| Phase | Duration | Key Deliverable |
|-------|----------|-----------------|
| Phase 1: Minimal Boot | 1-2 weeks | Shell on UART, SATA disks visible |
| Phase 2: Full HW | 3-6 weeks | Ethernet, I2C, thermal, fan control |
| Phase 3: Polish | 2-4 weeks | Production-ready, optimized |

**Total estimated effort**: 6-12 weeks

**Critical path**: AL Ethernet driver porting (Phase 2). Everything else is
straightforward because most peripherals use standard IP blocks with upstream
drivers. If an Intel PCIe NIC is acceptable as the network interface, the
entire project becomes dramatically simpler (Phase 2 drops to 1-2 weeks).

---

## 10. Decision Points

1. **Which kernel version?** Check kernel.org for latest LTS. Prefer 6.12.x
   or newer LTS.

2. **Native ethernet vs PCIe NIC?** If a PCIe slot is available and an Intel
   NIC is acceptable, skip the AL ethernet porting entirely. This removes
   the single biggest risk from the project.

3. **U-Boot: modify or work around?** If U-Boot doesn't support `booti`,
   we either need to wrap the kernel as uImage or flash a newer U-Boot.
   Flashing U-Boot is risky (potential brick). Prefer working with existing
   U-Boot.

4. **Micon control: kernel or userspace?** Userspace daemon is more flexible
   and doesn't require kernel porting. Kernel driver gives tighter integration
   (e.g., automatic fan control on thermal events).
