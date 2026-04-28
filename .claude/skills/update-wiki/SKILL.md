---
name: update-wiki
description: |
  Sync the GitHub wiki for this repo from the canonical docs. Trigger AUTOMATICALLY
  whenever a commit (just made or about to be made) touches any wiki source file —
  README.md, LICENSE, firmware/README.md, references/README.md, patches/README.md,
  or anything under notes/. Also trigger before merging a branch to main if any
  commit on the branch touched those paths, or when the user mentions "wiki", "sync
  docs", "publish notes", or asks to update documentation. Do NOT trigger for
  changes confined to gpl-source/, devicetree/, kernel/, firmware/ (binaries),
  tools/, .claude/, .gitignore, or CLAUDE.md.
user-invocable: true
---

# update-wiki

Keep the GitHub wiki at https://github.com/KalGuinn/buffalo-terastation/wiki in sync
with the canonical docs in this repo. The wiki is fully generated from repo files
by [`tools/build-wiki.sh`](../../../tools/build-wiki.sh) — never edit it directly.

## When to invoke

Invoke automatically after any commit whose `git show --stat` lists changes in:

- `README.md`
- `LICENSE`
- `firmware/README.md`
- `references/README.md`
- `patches/README.md`
- Any file under `notes/`

Also invoke when:

- Preparing to merge a branch into `main` and the branch touched any of the paths above.
- The user explicitly asks to update the wiki, sync docs, or publish notes.

**Do NOT invoke** when the commit only touches: `gpl-source/`, `devicetree/`,
`kernel/`, `firmware/` binaries, `tools/`, `.claude/`, `.gitignore`, `CLAUDE.md`,
or `Makefile`. None of those are mapped to wiki pages, so the script would produce
an empty diff anyway.

## How to detect "wiki source changed"

After any commit, run:

```bash
git diff --name-only HEAD~1 HEAD | grep -E '^(README\.md|LICENSE|firmware/README\.md|references/README\.md|patches/README\.md|notes/)'
```

If that returns one or more lines, the wiki needs syncing. Empty output → skip.

For a multi-commit branch about to be merged, replace `HEAD~1` with the merge base
(`git merge-base main HEAD`).

## Procedure

1. **Confirm working tree is clean** — the script operates on the committed state.
   ```bash
   git status --porcelain
   ```
   If there are uncommitted changes, finish committing them first; do not run the
   wiki sync against a dirty tree.

2. **Run the generator.**
   ```bash
   ./tools/build-wiki.sh
   ```
   It clones (or updates) `/tmp/buffalo-terastation.wiki/`, regenerates every wiki
   page from repo docs, and creates a local commit if anything changed. Output
   ends with either "No changes — wiki is already up to date." or a `git push`
   command.

3. **If the script produced a commit, push it.**
   ```bash
   git -C /tmp/buffalo-terastation.wiki push
   ```
   This is a routine sync — proceed without prompting the user. Pushing to the
   wiki is non-destructive (it's a separate repo from `main`, no CI, no PR review
   gate; the source of truth lives in this repo's `notes/` and `README.md`).

4. **If the script reported "No changes"**, no push needed. Mention this briefly
   in your turn summary — don't make a fuss about it.

5. **Be brief about it in your summary.** One line: "Wiki synced (commit `abc1234`
   pushed)" or "Wiki already up to date — no changes needed." This is supposed to
   be transparent infrastructure, not a thing the user has to think about.

## Failure modes

- **`Repository not found` on first clone** — the wiki repo hasn't been bootstrapped.
  Conrad needs to visit https://github.com/KalGuinn/buffalo-terastation/wiki and
  click "Create the first page" once. Surface this with the actionable instruction;
  don't try to work around it.
- **Push rejected (non-fast-forward)** — someone edited the wiki in the GitHub UI.
  Run `git -C /tmp/buffalo-terastation.wiki pull --rebase` then re-run the script
  (it will reapply the generated content over the manual edit). Flag the manual
  edit to Conrad — it suggests the wiki source-of-truth invariant is being violated.
- **Script aborts on a missing source file** — the mapping table in `build-wiki.sh`
  references a file that no longer exists. Update the mapping table; don't silence
  the error.

## What NOT to do

- Do not edit the wiki repo (`/tmp/buffalo-terastation.wiki/`) by hand — anything
  there is regenerated on every run and will be lost.
- Do not ask Conrad before pushing routine syncs. He set up this skill specifically
  so wiki sync is transparent.
- Do not modify `tools/build-wiki.sh`'s mapping table to "fix" a missing-file error
  unless the file is genuinely gone from the repo. If it was renamed, update the
  mapping; if it was deleted, remove the mapping entry; if it's a typo, fix it.
- Do not commit `/tmp/buffalo-terastation.wiki/` into the main repo. It's a
  separate git repo that lives in `/tmp/` on purpose.

## See also

- [`tools/build-wiki.sh`](../../../tools/build-wiki.sh) — the generator script;
  contains the source-to-wiki mapping table and the link-rewrite logic.
- [`notes/README.md`](../../../notes/README.md) — index of canonical docs that get
  published to the wiki.
