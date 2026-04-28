# References

Primary-source materials referenced during analysis. These are raw artifacts (datasheets, extracted snippets) — interpretation lives in [`../notes/`](../notes/).

## Datasheets
- [`datasheets/TS5020_Datasheet_V9.pdf`](datasheets/TS5020_Datasheet_V9.pdf) — Buffalo TeraStation TS5020 product datasheet (hardware specs, model variants)

## Kernel Snippets
Extracts from Buffalo's GPL release useful for cross-reference:
- [`kernel-snippets/buffalo_ts5020_defconfig.txt`](kernel-snippets/buffalo_ts5020_defconfig.txt) — Kernel `.config` Buffalo ships, source for [`../notes/hardware/hardware_catalog.md`](../notes/hardware/hardware_catalog.md)
- [`kernel-snippets/linux-4.19.75_r8125-9.012.04.patch`](kernel-snippets/linux-4.19.75_r8125-9.012.04.patch) — Realtek RTL8125 NIC out-of-tree driver patch (not in upstream `gpl-source/` patches)

## Firmware Snippets
Extracts from extracted firmware/rootfs:
- [`firmware-snippets/micon_v3.txt`](firmware-snippets/micon_v3.txt) — Micon (microcontroller) driver source snippet from rootfs
- [`firmware-snippets/uImage_dtbs.txt`](firmware-snippets/uImage_dtbs.txt) — U-Boot uImage / DTB layout reference
