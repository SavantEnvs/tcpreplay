---
name: Release Checklist
description: Walk through preparing a tcpreplay beta or full release, given a version number. Use when the user says things like "let's release 4.6.2", "prep a beta for X", "is <branch> ready for a release", or references the wiki Release Checklist.
---

## Release Checklist

Source of truth: https://github.com/appneta/tcpreplay/wiki/Release-Checklist
This skill loosely follows it, adapted to what actually happened preparing
4.6.1 on 2026-08-15 — read that as a worked example if anything here is
ambiguous.

Ask which of these the user wants before doing anything, since they change
the steps: **a beta** (pre-release, ships from a `-betaN` branch, no merge to
`master` yet) or **a full release** (ships from the clean version branch,
merges to `master` after).

### 1. Readiness check (do this first, always)

- `gh run list --branch <branch> --limit 5` — CI green on the latest commit?
- `git log origin/master..origin/<branch> --oneline | wc -l` — how far
  ahead of `master`, and does anything on `master` need pulling in first
  (`git log origin/<branch>..origin/master --oneline`)?
- Read the top of `docs/CHANGELOG` — does it match the branch's actual
  state? Any leftover beta-cycle headers that should be squashed into one?
- Report status plainly (ready / blockers) before touching anything. Don't
  assume "ready to release" means "go ahead and merge" — that's a separate
  confirmation.

### 2. Update CHANGELOG (checklist step 4)

- Top entry's date should be the actual release date, version should be the
  release's clean version number (not `-betaN`) even for a beta build — the
  suffix lives in the branch name and the tag, not the CHANGELOG header.
- Remove/squash beta-cycle sub-headers if any accumulated during
  development — one version header, one list of entries.
- Keep individual entries terse (1-2 lines) unless the user asks otherwise.

### 3. Update CREDIT (docs/CREDIT)

- Anyone who reported a security advisory (GHSA) fixed in this release gets
  an entry, grouped by reporter if they filed more than one — see the
  existing file for the pattern (e.g. `tinyb0y`, `tao pan`).
- Automated fuzzer findings (OSS-Fuzz) don't get individual CREDIT entries —
  they're credited in the CHANGELOG line itself (`OSS-Fuzz <issue-id>`), not
  here.

### 4. Version number (configure.ac)

- `AC_INIT([tcpreplay],[X.Y.Z],...)` — bump if not already done. Check
  `CMakeLists.txt` derives from this automatically (it does, via regex on
  configure.ac's version) rather than hardcoding a second copy.

### 5. Branch merges

Order matters less than making sure both directions happen before the next
step:
- If `master` has commits the release branch doesn't (e.g. a hotfix merged
  there directly), merge `master` into the release branch first.
- Merge the beta/working branch into the clean version branch (e.g.
  `4.6.1-beta1` → `4.6.1`), or create the clean version branch now if it
  doesn't exist yet.
- Push. Wait for CI green on the pushed branch before anything downstream
  depends on it.

### 6. Tagging, building, signing — not yours to do

You cannot create the actual git tag, build tarballs, or sign them — the
maintainer does this on a separate system with the signing key. Don't
attempt `git tag` on the release branch. If the user says "I've tagged and
built it," treat the tag as fixed: any further commits you make land *after*
it, and you should say so rather than silently pushing past it.

### 7. PR to master (full release only; skip for a beta)

- `gh pr create --base master --head <branch> --title "Release X.Y.Z"`.
- Check CI on the PR before merging — don't merge on a hunch, wait for
  green (`gh pr checks <number>`, poll if needed).
- After merge: run the [Delete Merged Branch](../delete-merged-branch/skill.md)
  skill's logic on the head branch, same as any other PR.

### 8. Release notes and announcement

- Draft release notes matching the style of the most recent actual release
  (`gh release view v<previous>` for the template) — highlights, a security
  table if applicable, a "What's Changed" list, download/verification
  instructions. Save as a file and hand it to the user rather than trying to
  create/publish the GitHub Release yourself — they attach it when uploading
  tarballs.
- If asked to announce: post to
  https://github.com/appneta/tcpreplay/discussions/categories/announcements
  via `gh discussion create --category Announcements`. Note that pinning a
  discussion has no API — that's a manual step via the `···` menu on the
  discussion page.
- A short mailing-list-style announcement email (overview, bullet summary,
  download link) is a nice companion — see 2026-08-15's 4.6.1 announcement
  for tone.

### 9. Cleanup

- Check for open GitHub milestones matching this version;
  close if any exist (often there aren't any — OSS-Fuzz findings and
  security advisories don't get milestones by default in this repo).
- Confirm `docs-deploy.yml`'s branch trigger list includes wherever the docs
  source actually lives post-merge (currently `master` plus whichever beta
  branch is active) — the live site only rebuilds on push to a listed
  branch with `docs/**` or `*_opts.def` changes.
