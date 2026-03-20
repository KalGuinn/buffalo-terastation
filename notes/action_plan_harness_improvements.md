# Claude Code Harness Improvements — Action Plan

Items to tackle in a dedicated session focused on tooling rather than the TeraStation project itself.

## 1. Custom Skills (1-2 hours)
Create project-specific skills in `.claude/skills/`:
- **firmware-extract** — Standardized firmware unpacking workflow with known passwords
- **patch-analysis** — Handle Buffalo's inverted diff format correctly
- **dts-validate** — Validate device tree files after editing
- **kernel-config** — Guide kernel configuration decisions against hardware catalog

## 2. Custom Agents (30 min)
Create specialized agents in `.claude/agents/`:
- **hardware-researcher** — Focused on identifying ICs, finding datasheets, updating hardware catalog

## 3. Hooks (1 hour)
Add automation hooks to `.claude/settings.local.json`:
- Post-edit DTS validation (run dtc after editing .dts/.dtsi files)
- Post-edit patch validation (dry-run patch application)
- Pre-commit checks (validate all DTS files compile)

## 4. Cross-Compilation Environment (1-2 hours)
- Set up Docker container with aarch64-linux-gnu toolchain
- Create Dockerfile in tools/docker/
- Configure env vars in settings for ARCH/CROSS_COMPILE
- Consider: could this container also be the isolated sandbox for bypassPermissions?

## 5. StatusLine Configuration (10 min)
- Show project context and current phase in the prompt bar

## Prerequisites
- Session restart (to pick up bypassPermissions)
- Git repo already initialized (done)
