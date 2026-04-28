# Kernel Version Check — 2026-03-20

Fetched from kernel.org via MCP fetch server.

## Current Versions
| Branch | Version | Date |
|--------|---------|------|
| mainline | 7.0-rc4 | 2026-03-15 |
| stable | 6.19.9 | 2026-03-19 |
| longterm | 6.18.19 | 2026-03-19 |
| longterm | **6.12.77** | 2026-03-13 |
| longterm | 6.6.129 | 2026-03-05 |
| longterm | 6.1.166 | 2026-03-05 |
| longterm | 5.15.202 | 2026-03-04 |

## Impact on TeraStation Strategy

The kernel build strategy doc (kernel_build_strategy.md) recommended **6.12 LTS**.
Current longterm is **6.18.19** — significantly newer.

### Recommendation Update
- **Target: 6.12.x LTS** remains a good choice — it's still actively maintained (6.12.77)
- **Alternative: 6.18.x** if we want the latest longterm with maximum driver maturity
- The `arch/arm64/boot/dts/amazon/` directory should have the most complete Alpine V2 DTS
- All the mainline drivers listed in the strategy doc will be present

### Next Steps
1. Check `arch/arm64/boot/dts/amazon/` in 6.18.x for Alpine V2 DTS files
2. Check if `CONFIG_ARCH_ALPINE` is still present in 6.18
3. Verify AL Ethernet driver status (was the biggest gap)
4. Download 6.18.19 tarball when devcontainer is ready
