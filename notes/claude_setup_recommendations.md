# Claude Code Setup Recommendations for TeraStation Project

Written 2026-03-19. Tailored for Conrad's firmware RE / kernel build workflow on macOS with Opus 4.6 (Max 20x).

---

## Table of Contents

1. [Current State Assessment](#1-current-state-assessment)
2. [Plugins and MCP Servers](#2-plugins-and-mcp-servers)
3. [Custom Skills](#3-custom-skills)
4. [Hooks](#4-hooks)
5. [CLAUDE.md Improvements](#5-claudemd-improvements)
6. [Settings and Permissions](#6-settings-and-permissions)
7. [Other Features](#7-other-features)

---

## 1. Current State Assessment

### What is already configured

- **Permissions (`.claude/settings.local.json`):** Well-structured allow list covering binary analysis tools (`binwalk`, `dtc`, `fdtdump`, `xxd`, `hexdump`, `strings`, `openssl`), git operations, archive tools, and general file operations. Deny list blocks `rm -rf`, `git push --force`, and `git reset --hard`.
- **CLAUDE.md:** Contains project overview, key context (inverted diffs, encrypted DTB), common tools list, and directory structure.
- **Memory files:** User profile, project status, reference links, firmware keys reference, and a feedback note about verifying Google Drive research files.
- **Plugins:** Context7 (documentation lookup) and Playwright (browser automation) are installed as MCP servers.

### What is missing

- No `.mcp.json` project-level MCP configuration file.
- No `~/.claude/settings.json` global settings file (or it is not readable).
- No custom skills directory (`.claude/skills/`).
- No hooks configured.
- No custom agents directory (`.claude/agents/`).
- CLAUDE.md is thin (30 lines) -- room for more actionable instructions.
- Not a git repo yet (no `.git/` directory at project root).

---

## 2. Plugins and MCP Servers

### Currently installed

| Plugin | Useful for this project? |
|--------|------------------------|
| Context7 | **Moderate.** Good for looking up kernel API docs, devicetree binding docs, U-Boot docs. Less useful for Buffalo-specific work. |
| Playwright | **Low.** Browser automation has limited value for firmware RE. Could uninstall to reduce context overhead. |

### Recommended additions

**GitHub MCP Server** -- If you push this project to GitHub (or already use GitHub for related repos like 1000001101000's Buffalo tools), the GitHub MCP server lets Claude read issues, search code across repos, and review PRs without leaving the session.

Install:
```bash
claude mcp add github -- npx -y @anthropic/github-mcp@latest
```

**Filesystem MCP Server** -- Not needed. Claude Code's built-in Read/Write/Edit/Glob/Grep tools already cover file operations thoroughly.

### What to skip

- **Database servers (PostgreSQL, Supabase):** No database in this project.
- **Figma, Slack, Linear:** Not relevant to firmware work.
- **Sequential Thinking:** Opus 4.6 with extended thinking already handles complex reasoning well. Adding this server would be redundant overhead.
- **Playwright:** Consider removing it. If you occasionally need to fetch web content, the built-in `WebFetch` and `WebSearch` tools are sufficient. Removing Playwright eliminates ~20 deferred tool definitions from context.

To remove Playwright:
```bash
claude plugin remove playwright
```

### Keeping Context7

Context7 is worth keeping. When working on kernel code, you can ask Claude to look up current devicetree binding documentation, kernel API changes between versions, or U-Boot command syntax with "use context7" in your prompt. This is especially valuable since you are bridging kernel 4.19 code to a modern kernel and need to know what APIs changed.

---

## 3. Custom Skills

Skills are markdown files in `.claude/skills/<name>/SKILL.md` that give Claude specialized instructions for specific tasks. They activate automatically when relevant or can be invoked with `/skill-name`.

### Recommended skills to create

#### 3.1 Firmware Extraction Skill

**File:** `.claude/skills/firmware-extract/SKILL.md`

```markdown
---
name: firmware-extract
description: Extract and analyze Buffalo TeraStation firmware images
autoActivate: when the user asks to extract, unpack, or analyze firmware
---

# Firmware Extraction

When extracting firmware from Buffalo TeraStation updater images:

1. Firmware updaters are ZIP files with password protection
2. Check ~/Claude/buffalo-terastation/notes/firmware_extraction_guide.md for known passwords
3. Use `7z` or `unzip` with the known password first
4. After extraction, run `binwalk -e` on the resulting image
5. Look for: kernel (uImage), DTB blobs, rootfs (squashfs), U-Boot
6. Always save extracted files to firmware/extracted/<version>/
7. Run `file` and `strings | head -50` on each extracted component
8. For DTB files, decompile with `dtc -I dtb -O dts`
```

#### 3.2 Patch Analysis Skill

**File:** `.claude/skills/patch-analysis/SKILL.md`

```markdown
---
name: patch-analysis
description: Analyze and fix Buffalo GPL source patches (which use inverted diff format)
autoActivate: when working with .patch or .diff files in the patches/ or gpl-source/ directories
---

# Patch Analysis

IMPORTANT: Buffalo's GPL source provides INVERTED diffs.
- Lines marked with `-` (removals) are actually Buffalo's ADDITIONS to the kernel
- Lines marked with `+` (additions) are actually the original kernel code they modified
- To create a correct patch, swap the sign of every hunk

When analyzing patches:
1. Identify which kernel subsystem is being modified
2. Note the base kernel version (4.19.75)
3. Determine if the change is: SoC support, board-specific, driver, or config
4. Flag any changes that reference Annapurna Labs / Amazon Alpine SoC specifics
5. Save corrected (un-inverted) patches to patches/fixed/
```

#### 3.3 DTS Validation Skill

**File:** `.claude/skills/dts-validate/SKILL.md`

```markdown
---
name: dts-validate
description: Validate and analyze Device Tree Source files
autoActivate: when editing or creating .dts or .dtsi files
---

# DTS Validation

When working with Device Tree Source files:

1. Always validate syntax by compiling: `dtc -I dts -O dtb -o /dev/null <file>.dts`
2. Check for warnings with: `dtc -I dts -O dtb -W all -o /dev/null <file>.dts`
3. Cross-reference node names against the hardware catalog at notes/hardware_catalog.md
4. Verify compatible strings against upstream kernel dt-bindings documentation
5. For the TS5020 series, the SoC is Annapurna Labs Alpine V2 (Amazon)
6. Compare against the extracted real DTBs in devicetree/ as ground truth
7. Note any nodes with unknown purpose in notes/dts_unknowns.md
```

#### 3.4 Kernel Config Skill

**File:** `.claude/skills/kernel-config/SKILL.md`

```markdown
---
name: kernel-config
description: Help build and analyze kernel configurations for TeraStation
autoActivate: when working with Kconfig, .config, or defconfig files
---

# Kernel Configuration

Target: Modern mainline kernel for Annapurna Labs Alpine V2 (ARM)
Base reference: Buffalo's 4.19.75 config from GPL source

When working on kernel config:
1. Start from arch/arm/configs/alpine_defconfig if it exists upstream
2. Cross-reference enabled drivers with the hardware catalog in notes/hardware_catalog.md
3. Essential subsystems: PCIe, I2C, SATA/AHCI, GPIO, network (10GbE), IPMI/BMC
4. Check notes/kernel_build_strategy.md for the current build plan
5. Flag any CONFIG options that are Buffalo-custom vs. upstream Alpine V2
```

### How to create these

```bash
mkdir -p ~/Claude/.claude/skills/firmware-extract
mkdir -p ~/Claude/.claude/skills/patch-analysis
mkdir -p ~/Claude/.claude/skills/dts-validate
mkdir -p ~/Claude/.claude/skills/kernel-config
# Then create each SKILL.md file
```

---

## 4. Hooks

Hooks are shell commands that fire automatically at specific lifecycle events. They are configured in `settings.json` (project or global).

### Recommended hooks

Add these to `.claude/settings.local.json` (or `.claude/settings.json` if you want them version-controlled):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "file=$(echo $CLAUDE_TOOL_INPUT | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"file_path\",\"\"))'); if [[ \"$file\" == *.dts || \"$file\" == *.dtsi ]]; then dtc -I dts -O dtb -o /dev/null \"$file\" 2>&1 || true; fi"
          }
        ]
      }
    ]
  }
}
```

This hook automatically validates DTS files after every edit. If `dtc` reports errors, Claude will see them and can fix them immediately.

### Other hook ideas (add as needed)

- **Post-edit patch validator:** After editing `.patch` files, verify they apply cleanly with `patch --dry-run`.
- **Pre-commit DTB check:** Before any git commit, compile all `.dts` files to catch syntax errors.
- **File size warning:** After Write operations, warn if a binary file was accidentally written to a source directory.

### Hook implementation note

Hook commands receive JSON on stdin with tool input details. Use `python3 -c` one-liners or small scripts in `tools/hooks/` to parse the JSON and decide whether to act.

---

## 5. CLAUDE.md Improvements

Your current CLAUDE.md is functional but minimal. Here is a recommended expanded version. Keep it under 200 lines -- Claude's adherence drops on longer files.

### Additions to make

**Add these sections to `/Users/conrad/Claude/CLAUDE.md`:**

```markdown
## SoC Identity
- SoC: Annapurna Labs Alpine V2 (acquired by Amazon, ARM Cortex-A57)
- Model: TS51220RH9612 (TS5020 series, 12-bay rackmount)
- Original kernel: 4.19.75 (Ubuntu-based, Buffalo-modified)
- Target: Modern mainline kernel (6.x)

## Working Conventions
- ALWAYS check notes/ directory for existing research before starting new analysis
- Binary files go in firmware/, never in source directories
- Corrected patches go in patches/fixed/, originals stay in patches/
- When unsure about hardware details, cross-reference notes/hardware_catalog.md
- Device tree ground truth: devicetree/ contains DTBs extracted from real firmware

## File Naming
- Patches: <subsystem>-<description>.patch (e.g., pcie-alpine-v2-init.patch)
- Notes: snake_case.md
- DTS files: Use upstream naming conventions (alpine-v2-*.dts)

## Common Pitfalls
- Buffalo diffs are INVERTED: their `-` lines are additions, `+` lines are originals
- DTBs in U-Boot images appeared encrypted but were actually in the firmware updater ZIP
- Google Drive research files from prior AI Studio sessions may contain errors -- verify against primary sources
- The NAS is currently offline; prefer firmware RE approaches over live system methods

## Cross-Compilation
- Toolchain: [specify your cross-compiler, e.g., arm-linux-gnueabihf-]
- ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
- Build output: kernel/build/

## Useful Commands
- Decompile DTB: `dtc -I dtb -O dts -o output.dts input.dtb`
- Validate DTS: `dtc -I dts -O dtb -o /dev/null input.dts`
- Extract firmware: `7z x -p<password> firmware.exe`
- Analyze binary: `binwalk -e <image>`
- Check patch: `patch --dry-run -p1 < patch.patch`
```

### Use sub-directory CLAUDE.md files

Add focused instructions in subdirectories so Claude gets relevant context automatically:

- `devicetree/CLAUDE.md` -- DTS naming conventions, validation commands, SoC-specific notes
- `patches/CLAUDE.md` -- The inverted diff rule (critical, worth repeating), patch naming
- `kernel/CLAUDE.md` -- Build commands, cross-compilation setup, config conventions

---

## 6. Settings and Permissions

### Current permissions assessment

Your allow list is solid for this project. A few additions to consider:

```json
{
  "permissions": {
    "allow": [
      "Bash(make:*)",
      "Bash(patch:*)",
      "Bash(readelf:*)",
      "Bash(objdump:*)",
      "Bash(nm:*)",
      "Bash(arm-linux-gnueabihf-*:*)",
      "Bash(dd:*)",
      "Bash(cpio:*)",
      "Bash(stat:*)",
      "Bash(sha1sum:*)",
      "Bash(od:*)",
      "Bash(tee:*)",
      "Bash(grep:*)",
      "Bash(awk:*)",
      "Bash(sed:*)",
      "Bash(cut:*)",
      "Bash(tr:*)",
      "Bash(xargs:*)",
      "Bash(git push:*)",
      "Bash(git clone:*)",
      "Bash(git fetch:*)",
      "Bash(git pull:*)",
      "Bash(git rebase:*)",
      "Bash(git tag:*)",
      "Bash(rm:*)"
    ]
  }
}
```

Key additions explained:
- **`make`, `patch`**: Essential for kernel builds and patch management -- currently missing.
- **`readelf`, `objdump`, `nm`**: ELF binary analysis tools for inspecting kernel modules and firmware binaries.
- **Cross-compiler prefix**: Allow the ARM cross-compilation toolchain.
- **`dd`, `cpio`**: Common for firmware image manipulation and kernel initramfs work.
- **Text processing (`grep`, `awk`, `sed`, `cut`, `tr`, `xargs`)**: Claude currently uses built-in Grep but sometimes needs these in pipelines.
- **`rm`** (without `-rf`): Allow removing individual files. Your deny rule for `rm -rf` still protects against recursive deletion.
- **Additional git commands**: `push`, `clone`, `fetch`, `pull` for normal git workflow.

### Deny list additions

```json
{
  "deny": [
    "Bash(rm -rf:*)",
    "Bash(git push --force:*)",
    "Bash(git reset --hard:*)",
    "Bash(dd of=/dev/*:*)"
  ]
}
```

Add `dd of=/dev/*` to prevent accidental writes to device nodes (unlikely on macOS but good practice for a project involving disk images).

### Environment variables

Add to settings if you have a cross-compiler installed:

```json
{
  "env": {
    "ARCH": "arm",
    "CROSS_COMPILE": "arm-linux-gnueabihf-",
    "KBUILD_OUTPUT": "/Users/conrad/Claude/buffalo-terastation/kernel/build"
  }
}
```

---

## 7. Other Features

### Git initialization

Your project is not a git repo. Initialize one:

```bash
cd ~/Claude/buffalo-terastation
git init
```

This unlocks worktrees, commit hooks, proper diff tracking, and lets Claude use its full git toolset. Add a `.gitignore` for large binaries in `firmware/`.

### Worktrees (parallel agents)

Once you have a git repo, worktrees let you run multiple Claude sessions in parallel without conflicts. Useful for:
- One session analyzing patches while another works on DTS files
- Running a kernel build in one worktree while researching in another

Usage: `claude --worktree dts-work` creates an isolated branch and directory.

### Custom Agents

Create specialized agents in `.claude/agents/` for focused tasks:

**File:** `.claude/agents/hardware-researcher.md`

```markdown
---
name: hardware-researcher
description: Research hardware components and update the hardware catalog
model: claude-opus-4-6
---

You are a hardware research specialist. Your job is to:
1. Identify hardware components from device tree nodes, kernel drivers, and datasheets
2. Find datasheets and documentation for identified ICs
3. Update notes/hardware_catalog.md with findings
4. Cross-reference with the extracted DTS files in devicetree/

Always cite sources. Focus on components relevant to the TS5020 series TeraStation.
```

Invoke with: `/agent hardware-researcher`

### StatusLine

StatusLine shows persistent info in the Claude Code prompt bar. Not heavily documented yet, but you can set it in settings:

```json
{
  "statusLine": "TeraStation RE | Alpine V2 ARM | Kernel 4.19→6.x"
}
```

This is a minor quality-of-life feature -- it reminds you (and Claude) of the project context at a glance.

### Memory files

Your memory setup is already good. Consider adding:
- `reference_kernel_versions.md` -- Track which kernel versions you have tested, what works, what does not
- `reference_hardware_ids.md` -- PCI vendor/device IDs, I2C addresses, GPIO pin mappings extracted from the DTS

### Voice mode

Claude Code supports voice input. For a terminal-native workflow it is probably not a priority, but it can be useful for dictating research notes hands-free while examining hardware.

---

## Quick-Start Action Items

Priority order for immediate improvements:

1. **Initialize git repo** in `buffalo-terastation/` (unlocks worktrees, proper diffing, commit tracking)
2. **Expand CLAUDE.md** with SoC identity, working conventions, and common commands (Section 5)
3. **Add missing permissions** -- especially `make`, `patch`, `readelf`, and text processing tools (Section 6)
4. **Create the DTS validation skill** (Section 3.3) -- most immediately useful given your current project phase
5. **Create the patch analysis skill** (Section 3.2) -- critical for the inverted-diff problem
6. **Remove Playwright plugin** if not using it -- reduces context noise
7. **Add DTS validation hook** (Section 4) -- catches syntax errors automatically
8. **Create sub-directory CLAUDE.md files** for devicetree/ and patches/ (Section 5)

---

## Sources

- [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices)
- [Claude Code MCP Configuration](https://code.claude.com/docs/en/mcp)
- [Context7 MCP Server (Upstash)](https://github.com/upstash/context7)
- [Claude Code Common Workflows](https://code.claude.com/docs/en/common-workflows)
- [CLAUDE.md Best Practices (UX Planet)](https://uxplanet.org/claude-md-best-practices-1ef4f861ce7c)
- [How to Write a Good CLAUDE.md (Builder.io)](https://www.builder.io/blog/claude-md-guide)
- [Awesome Claude Code (GitHub)](https://github.com/hesreallyhim/awesome-claude-code)
- [Claude Code for Firmware Development (Beningo)](https://www.beningo.com/why-claude-code-for-firmware-development-matters/)
