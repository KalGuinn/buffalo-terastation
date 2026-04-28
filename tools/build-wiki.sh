#!/usr/bin/env bash
# build-wiki.sh — generate the GitHub wiki for buffalo-terastation from repo docs.
#
# The wiki is a separate git repo (buffalo-terastation.wiki.git). This script:
#   1. Clones (or updates) the wiki repo into a working directory
#   2. Copies repo docs into wiki pages, rewriting cross-doc links and repo-file
#      links so they resolve correctly inside the wiki
#   3. Generates Home.md, _Sidebar.md, _Footer.md
#   4. Commits the changes locally; the user reviews `git diff` and pushes manually
#
# One-time setup before first run: visit https://github.com/KalGuinn/buffalo-terastation/wiki
# and click "Create the first page" with any content (e.g. "placeholder"). GitHub
# creates the underlying wiki repo lazily; this script can't do it for you.
#
# Usage: from anywhere inside the repo, run `./tools/build-wiki.sh [WIKI_DIR]`
# WIKI_DIR defaults to /tmp/buffalo-terastation.wiki

set -euo pipefail

# --- config ------------------------------------------------------------------

REPO_OWNER="KalGuinn"
REPO_NAME="buffalo-terastation"
WIKI_REMOTE="https://github.com/${REPO_OWNER}/${REPO_NAME}.wiki.git"
BLOB_BASE="https://github.com/${REPO_OWNER}/${REPO_NAME}/blob/main"
WIKI_DIR="${1:-/tmp/${REPO_NAME}.wiki}"

# --- locate repo root --------------------------------------------------------

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
SHORT_SHA="$(git rev-parse --short HEAD)"

# --- mapping table (source path → wiki page basename, no .md) ---------------
# Maintained as two parallel space-delimited columns for bash 3.2 portability.
# Keep this list in sync with the plan.

read -r -d '' MAPPING <<'EOF' || true
README.md|Home
firmware/README.md|Firmware-Acquisition
notes/firmware/extraction_guide.md|Firmware-Extraction-Guide
notes/firmware/rootfs_analysis.md|Rootfs-Analysis-and-Micon-Protocol
notes/hardware/ts51220_hardware_summary.md|Hardware-Summary-TS51220
notes/hardware/hardware_catalog.md|Alpine-V2-Hardware-Catalog
notes/hardware/dts_unknowns.md|Known-Hardware-Limitations
notes/kernel/build_strategy.md|Mainline-Kernel-Build-Strategy
notes/kernel/kernel_version_selection.md|Kernel-Version-Selection
notes/community_research.md|Community-Research-and-Prior-Art
notes/project_status_and_next_steps.md|Project-Roadmap
references/README.md|Reference-Materials
patches/README.md|GPL-Patch-Conventions
LICENSE|License-and-Attribution
EOF

# --- prepare wiki working copy -----------------------------------------------

if [[ -d "$WIKI_DIR/.git" ]]; then
    echo "Updating existing wiki clone at $WIKI_DIR"
    git -C "$WIKI_DIR" fetch --quiet origin
    git -C "$WIKI_DIR" reset --quiet --hard origin/master 2>/dev/null \
        || git -C "$WIKI_DIR" reset --quiet --hard origin/main
else
    echo "Cloning wiki repo into $WIKI_DIR"
    if ! git clone --quiet "$WIKI_REMOTE" "$WIKI_DIR" 2>/tmp/wiki-clone.err; then
        cat /tmp/wiki-clone.err >&2
        cat >&2 <<EOM

ERROR: could not clone $WIKI_REMOTE

If the error above is "Repository not found", the wiki repo doesn't exist yet.
Bootstrap it manually:
  1. Open https://github.com/${REPO_OWNER}/${REPO_NAME}/wiki
  2. Click "Create the first page" — any content is fine, you'll overwrite it
  3. Save, then re-run this script
EOM
        exit 1
    fi
fi

# Wipe everything we manage; we'll regenerate. Anything left under .git/ stays.
find "$WIKI_DIR" -maxdepth 1 -type f -name '*.md' -delete

# --- rewrite engine (Python) -------------------------------------------------
# Reads the mapping from stdin (one "source|wiki" per line), then for each
# mapped source, writes the transformed content to $WIKI_DIR/<wiki>.md.
#
# Link rewrite rules:
#   1. Markdown link target that resolves (relative to the source file's
#      directory) to a path in the mapping → rewrite to the wiki page name,
#      preserving any #anchor fragment.
#   2. Markdown link target that resolves to any other in-repo path →
#      rewrite to ${BLOB_BASE}/<repo-relative-path>, preserving the fragment.
#   3. Absolute http(s) URLs and bare anchors (#foo) → leave alone.
#
# Also strips a leading H1 from the source (if any) and replaces it with a
# wiki-canonical "# <Title with spaces>" — GitHub's wiki shows the page name
# as the H1 header anyway, but we keep an explicit one for in-page TOCs.

export MAPPING_TEXT="$MAPPING"
python3 - "$REPO_ROOT" "$WIKI_DIR" "$BLOB_BASE" <<'PYEOF'
import os, re, sys
from pathlib import Path

repo_root, wiki_dir, blob_base = sys.argv[1], sys.argv[2], sys.argv[3]
repo_root = Path(repo_root).resolve()
wiki_dir = Path(wiki_dir).resolve()

mapping = {}  # source-path (repo-relative) → wiki-name
order = []
mapping_text = os.environ["MAPPING_TEXT"]
for line in mapping_text.strip().splitlines():
    src, wiki = line.split("|", 1)
    mapping[src] = wiki
    order.append((src, wiki))

LINK_RE = re.compile(r'(\[[^\]]*\])\(([^)]+)\)')

def rewrite_target(target: str, source_dir: Path) -> str:
    # Leave absolute URLs, mailto, anchors, and obvious non-paths alone.
    if target.startswith(("http://", "https://", "mailto:", "#")):
        return target

    # Split off any #fragment.
    if "#" in target:
        path_part, frag = target.split("#", 1)
        frag = "#" + frag
    else:
        path_part, frag = target, ""

    if not path_part:
        return target  # bare anchor, already handled above but defensive

    # Resolve relative to the source file's directory.
    try:
        resolved = (source_dir / path_part).resolve()
        rel = resolved.relative_to(repo_root).as_posix()
    except (ValueError, OSError):
        return target  # outside repo or unresolvable — leave alone

    # If this path is in the mapping, link to the wiki page.
    if rel in mapping:
        return mapping[rel] + frag

    # Special case: LICENSE has no extension; mapping handles it as "LICENSE".
    if rel == "LICENSE":
        return mapping["LICENSE"] + frag

    # Otherwise, point at the file in the repo on GitHub.
    return f"{blob_base}/{rel}{frag}"

def rewrite_links(md: str, source_path: Path) -> str:
    source_dir = source_path.parent
    def repl(m):
        text, target = m.group(1), m.group(2)
        return f"{text}({rewrite_target(target, source_dir)})"
    return LINK_RE.sub(repl, md)

def title_from_wiki_name(wiki: str) -> str:
    return wiki.replace("-", " ")

for src, wiki in order:
    src_path = repo_root / src
    if not src_path.exists():
        print(f"  SKIP missing: {src}", file=sys.stderr)
        continue

    raw = src_path.read_text()

    # Special-case LICENSE: not markdown, wrap it.
    if src == "LICENSE":
        body = "# License and Attribution\n\n```\n" + raw.rstrip() + "\n```\n"
    else:
        body = rewrite_links(raw, src_path)

    out = wiki_dir / f"{wiki}.md"
    out.write_text(body)
    print(f"  wrote {out.name}  (from {src})")

# --- generate _Sidebar.md ---------------------------------------------------

sidebar = """\
**[Home](Home)**

**Getting started**
- [Project overview](Home)
- [Firmware acquisition](Firmware-Acquisition)
- [Firmware extraction guide](Firmware-Extraction-Guide)

**Hardware**
- [TS51220 hardware summary](Hardware-Summary-TS51220)
- [Alpine V2 hardware catalog](Alpine-V2-Hardware-Catalog)
- [Known hardware limitations](Known-Hardware-Limitations)

**Firmware internals**
- [Rootfs & micon protocol](Rootfs-Analysis-and-Micon-Protocol)

**Kernel build**
- [Mainline build strategy](Mainline-Kernel-Build-Strategy)
- [Kernel version selection](Kernel-Version-Selection)
- [GPL patch conventions](GPL-Patch-Conventions)

**Project**
- [Roadmap](Project-Roadmap)
- [Community research & prior art](Community-Research-and-Prior-Art)
- [Reference materials](Reference-Materials)
- [License & attribution](License-and-Attribution)
"""
(wiki_dir / "_Sidebar.md").write_text(sidebar)
print("  wrote _Sidebar.md")

footer = (
    "Generated from the [repo docs](https://github.com/KalGuinn/buffalo-terastation) "
    "by `tools/build-wiki.sh`. License: MIT (this project) · GPL-2.0 (vendor sources).\n"
)
(wiki_dir / "_Footer.md").write_text(footer)
print("  wrote _Footer.md")
PYEOF

# --- commit ------------------------------------------------------------------

cd "$WIKI_DIR"

# Configure identity locally only (don't pollute global config) if missing.
if ! git config user.email >/dev/null; then
    git config user.email "$(git -C "$REPO_ROOT" config user.email)"
    git config user.name  "$(git -C "$REPO_ROOT" config user.name)"
fi

git add -A
if git diff --cached --quiet; then
    echo
    echo "No changes — wiki is already up to date."
    exit 0
fi

git commit -q -m "Sync wiki from repo @ ${SHORT_SHA}"

echo
echo "=== Wiki updated locally at $WIKI_DIR ==="
git --no-pager log -1 --stat
echo
echo "Review the diff, then push with:"
echo "  git -C $WIKI_DIR push"
