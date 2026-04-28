# Kernel Version Selection

_Last refreshed: 2026-04-27 (snapshot from kernel.org via MCP fetch)_

Companion to [`build_strategy.md`](build_strategy.md). Refresh this page whenever a new
LTS branch becomes the recommended target — at minimum once per kernel.org LTS rotation.

## Reference snapshot of kernel.org

| Branch | Version | Date |
|--------|---------|------|
| mainline | 7.0-rc4 | 2026-03-15 |
| stable | 6.19.9 | 2026-03-19 |
| longterm | 6.18.19 | 2026-03-19 |
| longterm | **6.12.77** | 2026-03-13 |
| longterm | 6.6.129 | 2026-03-05 |
| longterm | 6.1.166 | 2026-03-05 |
| longterm | 5.15.202 | 2026-03-04 |

## Recommended target for this project

**6.12.x LTS** is the working target.

- Actively maintained (point release within the last week of the snapshot above)
- First LTS to land the bulk of upstream Alpine V2 cleanups
- Stable enough that vendor-driver back-ports from 4.19 are still tractable

**6.18.x LTS** is a viable alternative if maximum driver maturity matters more than back-port effort. Choose this if you discover during port work that important fixes only landed post-6.12.

Older LTS branches (6.6, 6.1, 5.15) are not worth targeting for new work — the goal is to be on a kernel that will still be receiving CVE fixes years from now.

## What to verify on the target tree

Before committing to a version, check the following in the chosen tree:

1. **`arch/arm64/boot/dts/amazon/`** — confirm Alpine V2 DTSI files are present and reasonably complete. This directory is where the upstream platform DTS lives.
2. **`CONFIG_ARCH_ALPINE`** — confirm the platform symbol is still present in `arch/arm64/Kconfig.platforms`.
3. **AL Ethernet driver status** — historically the biggest gap. Check `drivers/net/ethernet/amazon/` — if `al_eth` is present, that closes a multi-week porting task.
4. **PCIe controller drivers** — `drivers/pci/controller/pcie-alpine.c` (or similar) for the internal PCIe roots. Without these, no SATA, no ethernet, nothing.
5. **AL FIC / IOFIC interrupt controllers** — `drivers/irqchip/`; these aggregate interrupts from SoC blocks and are required for correct IRQ routing once moving off PCI-discovered interrupts.

## Update procedure

When refreshing this page:

1. Re-fetch kernel.org's `releases.json` to update the version table.
2. Re-check the five items above on the new target tree.
3. Update the **Last refreshed** date at the top.
4. If the recommended target changes, note the reason in a short changelog at the bottom of the page.

## Changelog

- **2026-04-27** — Initial publication. Recommendation: 6.12 LTS.
