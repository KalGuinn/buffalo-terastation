# TS5020/TS51220 Rootfs Analysis

Extracted from v2.98 SquashFS rootfs (`hddrootfs.buffalo.updated`).

## Boot Sequence (from etc/init.d/buffalo-rc)

1. `miconapl -D start` — Micon daemon (hardware controller, first thing started)
2. `errormon` — Error monitoring daemon
3. `miconapl -a boot_start2` — Signal boot progress to micon
4. `buttond` — Front panel button handler
5. Kernel modules loaded
6. `kernelmon.sh` — Kernel event monitor
7. `hddplugmon.sh` — Hot-plug disk monitoring
8. `miconmon.sh` — Micon status monitor
9. `fanctld.sh` — Fan control daemon
10. `micon_setup.sh` — Micon initial configuration
11. `diskmon.sh` — Disk health monitoring
12. `raidkeeper.sh` — RAID management
13. `dwarf.sh` — Buffalo's web management daemon
14. `bootcomplete.sh` — Signal boot complete
15. `kernelmon_exec.sh psu_check` — PSU status check

## Micon Interface

**Device:** `/dev/micon_port` (created by udev symlink)
- TS5020/TS51220: USB serial adapter via PCIe-external0 USB hub
- TS3030: Direct UART at `fd885000.uart2`

**Main binary:** `/usr/local/sbin/miconapl`
- Config: `/etc/miconapl.conf`
- PID: `/var/run/miconapl.pid`
- Socket: `/var/run/miconapl.sock` (IPC for other daemons)
- Invoked as: `miconapl -a <command>` for one-shot, `miconapl -D start` for daemon

## Complete Micon Command Set (from strings analysis of miconapl)

### Boot/System State
| Command | Purpose |
|---------|---------|
| `boot_start` | Signal boot beginning |
| `boot_dram_ok` | DRAM init passed |
| `boot_flash_ok` | Flash init passed |
| `boot_hdd_ok` | HDD init passed |
| `boot_device_ok` | Device init passed |
| `boot_device_error` | Device init failed |
| `boot_dramad_ng` / `boot_dramdt_ng` | DRAM errors |
| `boot_end` | Boot complete |
| `boot_error_del` | Clear boot errors |
| `auto_boot` / `auto_boot_on` / `auto_boot_off` | Auto-boot control |

### Power Management
| Command | Purpose |
|---------|---------|
| `power_off` | Shutdown |
| `reboot` | Reboot |
| `power_state` | Query power state |
| `shutdown_wait` | Enter shutdown wait |
| `shutdown_cancel` | Cancel pending shutdown |
| `wol_ready` / `wol_ready_on` / `wol_ready_off` | Wake-on-LAN |
| `wol_ready_uboot_passed` | WOL handoff to U-Boot |

### Fan Control
| Command | Purpose |
|---------|---------|
| `fan_get_speed` | Read current RPM |
| `fan_get_speed_ex` | Extended speed info |
| `fan_set_speed` | Set speed (slow/full/fast/silen) |
| `temp_get` | Read temperature |

### LED Control
| Command | Purpose |
|---------|---------|
| `led_set_on_off` | Turn LED on/off |
| `led_set_blink` / `led_set_brink` | Set LED blinking |
| `led_set_bright` | Set LED brightness |
| `led_set_code_error` | Set error LED pattern |
| `led_set_code_information` | Set info LED pattern |
| `led_set_cpu_mcon` | CPU/micon status LED |
| `sata_led_set_on_off` | Disk activity LED on/off |
| `sata_led_set_blink` / `sata_led_set_brink` | Disk LED blink |
| `all_on` | All LEDs on (test mode) |

### LCD Display (front panel)
| Command | Purpose |
|---------|---------|
| `lcd_init` | Initialize LCD |
| `lcd_set_bright` / `lcd_set_contrast` | Display settings |
| `lcd_set_hostname` | Show hostname |
| `lcd_set_ipaddress` | Show IP address |
| `lcd_set_linkspeed` | Show link speed |
| `lcd_set_raidmode` | Show RAID mode |
| `lcd_set_date` | Show date/time |
| `lcd_set_disk_capacity` | Show disk usage |
| `lcd_disp_*` | Various display modes |
| `lcd_changemode_auto` / `lcd_changemode_button` | LCD cycle mode |
| `lcd_get_dispplane` | Get current display |
| `lcd_set_dispitem` | Set display item |

### Disk/HDD
| Command | Purpose |
|---------|---------|
| `hdd_set_power` / `hdd_set_power_on` / `hdd_set_power_off` | Disk power control |
| `usb_set_power` | USB port power control |

### Buzzer
| Command | Purpose |
|---------|---------|
| `bz_on` | Buzzer on |
| `bz_imhere` | "I'm here" beep pattern |
| `bz_disp_on` / `bz_disp_off` | Buzzer display mode |
| `bz_set_freq` | Set buzzer frequency |
| `melody_*` | Play melody |
| `twinkle_star` | Play twinkle star melody |
| `tone_check` | Test buzzer tone |

### UPS
| Command | Purpose |
|---------|---------|
| `ups_linefail_on` / `ups_linefail_off` | AC power fail status |
| `ups_shutdown` / `ups_shutdown_on` / `ups_shutdown_off` | UPS shutdown control |
| `ups_recover` / `ups_recover_on` / `ups_recover_off` | UPS recovery |
| `ups_test_port` | Test UPS serial port |
| `ups_vender_apc` / `ups_vender_omron` | UPS vendor selection |

### System Info
| Command | Purpose |
|---------|---------|
| `mcon_get_version` | Micon firmware version |
| `mcon_get_status` | Micon status |
| `mcon_get_taskdump` | Micon task dump (debug) |
| `board_id` | Board identification |
| `get_hw_revision_id` | Hardware revision |
| `get_psu_status` | Power supply status |
| `system_get_mode` | System mode |
| `system_set_watchdog` | Hardware watchdog |
| `int_get_switch_status` | Physical switch state |

### Misc
| Command | Purpose |
|---------|---------|
| `im_here` | Heartbeat/keepalive |
| `normal_state` | Enter normal operating state |
| `serialmode_console` | Switch serial to console mode |
| `update_fw` | Firmware update mode |
| `diag` | Diagnostic mode |
| `enable_debug` | Enable debug output |
| `trace_cmd` / `trace_pkt` | Trace commands/packets |

## GPIO Usage (from udev rules + miconapl strings)

### TS5020 (gpiochip4)
- GPIO 476-478: Hardware revision ID bits (hw_rev_id1/2/3)

### TS3030 (gpiochip0 + gpiochip3 + gpiochip4)
- GPIO 505: Info LED
- GPIO 486-487: Drive 1-2 power status
- GPIO 472-473: Drive 3-4 power status
- GPIO 475-478: Drive 1-4 plugged status (active low)
- GPIO 479: Reset button (active low)
- GPIO 465: Function LED

### TS5020/TS51220 Micon-managed GPIO
- `/dev/gpio/drive1_plugged_status` through `drive4_plugged_status`
- `/dev/gpio/drive1_power_status` through `drive4_power_status`
- `/dev/gpio/func_led`
- `/dev/gpio/info_led`
- `/dev/gpio/reset_button`

## Other Hardware Daemons

| Binary | Purpose |
|--------|---------|
| `fanctld` | Fan speed control daemon (temperature-based) |
| `errormon` | Error monitoring and reporting |
| `miconmon` | Micon status polling |
| `pwrmgr` | Power management (standby/wake) |
| `buttond` | Front panel button handler |
| `daemonwatch` | Watchdog for other daemons |
| `kernelmon` | Kernel event monitor |
| `hddplugmon-daemon.sh` | Hot-plug disk detection |
| `diskmon` | Disk health (SMART) monitoring |
| `dwarf` / `dwarfd` / `dwarves` | Buffalo web management UI |

## Network Defaults (from etc/default/buffalo)

```
DEFAULT_IP=192.168.11.150
ENETNAME=eth0
ENETNAME2=eth1
```

## Key Takeaway for Custom Kernel

The micon interface is entirely userspace — it talks over a serial port (`/dev/micon_port`) using a text-based protocol. The kernel just needs to provide:
1. USB serial driver (for the USB-serial adapter on PCIe)
2. GPIO access (for drive status, LEDs, buttons)
3. The standard SATA, network, and I2C drivers

All hardware management (fans, LEDs, LCD, buzzer, power) is handled by `miconapl` in userspace. This simplifies the kernel build significantly — no custom kernel modules needed for hardware management, just the standard subsystems.
