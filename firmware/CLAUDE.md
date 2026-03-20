# Firmware Files

Large binary files — do NOT commit to git (covered by .gitignore).

## Structure
- `win298/` — v2.98 Windows firmware updater (fully extractable)
- `win308/` — v3.08 Windows firmware updater (DTBs extractable, other images have extra encryption)
- `rootfs/` — Selectively extracted files from the v2.98 SquashFS rootfs

## Extraction Passwords
See memory file `reference_firmware_keys.md` for ZIP passwords.
- v2.98: `1NIf_2yUOlRDpYZUVNqboRpMBoZwT4PzoUvOPUp6l`
- v3.08: `aAhvlM1Yp7_2VSm6BhgkmTOrCN1JyE0C5Q6cB3oBB` (u-boot.img only fully decrypts)

## Mac firmware updaters
The .dmg.zip files in the project root are the macOS versions — not yet analyzed.
