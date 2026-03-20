# Device Tree Files

## Ground Truth
The `.dtb` files here were extracted directly from Buffalo firmware v2.98 and are byte-identical to v3.08.
The `.dts` files were decompiled from those DTBs using `dtc -I dtb -O dts`.

## Files
- `alpine-ts51220.dtb/dts` — Conrad's exact model (TS51220RH9612, 12-bay rackmount)
- `alpine-ts5020.dtb/dts` — Standard TS5020 (8-bay desktop)
- `alpine-ts3030.dtb/dts` — TS3030 variant
- `alpine-ts3030r.dtb/dts` — TS3030R variant
- `alpine-ts51220-annotated.dts` — Fully annotated version with decoded hex values
- `alpine-v2-ts5020.dts` — Early draft reconstruction (before real DTBs were extracted, historical only)

## Validation
Always validate DTS changes: `dtc -I dts -O dtb -o /dev/null <file>.dts`

## Key Differences: TS51220 vs TS5020
- TS51220 has PCA9548 I2C mux (TS5020 does not)
- TS51220 bays 5-12 use PCIe-attached SAS HBAs; TS5020 uses native SATA for all bays
- Different SerDes tuning parameters
- Micon on both is USB serial via PCIe (not direct UART like TS3030)
