---
name: Delete Merged Branch
description: After merging a PR in this repo, clean up the head branch unless it's protected. Use whenever a `gh pr merge` succeeds.
---

## Delete Merged Branch

After merging a PR (`gh pr merge`), delete its head branch on origin — unless
it's protected. Stale merged branches accumulate fast in this repo (56 got
swept in one pass on 2026-08-15), and nobody references a feature/fix branch
by name once its work has landed on the target branch.

### Protected — leave these alone

- `master` (and `main`, if ever renamed)
- A bare version-number branch: `^v?[0-9]+(\.[0-9]+)*$` — e.g. `4.6.1`,
  `4.6.0`, `3.4`. These are permanent release-history branches, not
  work-in-progress.
- Anything the user names as an exception for this merge. Example from
  2026-08-15: `4.6.1-beta1` had to stay because an external OSS-Fuzz build
  config (`project.yaml`) still pointed its fuzzing job at that branch name.
  If unsure whether such a pin still applies, ask rather than assume it's
  gone.

### Not protected — delete these, even if they look version-ish

A version number *with a suffix* (`4.6.0-alpha`, `4.5.0-beta3`,
`v4.5.3-beta2`) is not a permanent branch — it's leftover from a pre-release
cycle that's over. Default to deleting it. The same goes for anything
descriptive (`fix-*`, `Bug_*`, `credit-*`, PR-author feature branches, etc.).
When genuinely unsure whether a branch name is "version-like enough" to
protect, treat it as not protected — the cost of a mistaken delete is low
(commits stay reachable via the target branch's history for anything that
was actually merged; `git reflog`/GitHub's branch-restore banner covers the
rest for a while), and the point of this skill is to stop clutter from
piling up.

### How

```
gh pr merge <number> --merge --delete-branch
```

`--delete-branch` handles both the merge and cleanup in one call. If you
already merged without it, delete separately:

```
git push origin --delete <branch>
```

Either way, confirm and mention the branch is gone (or why it was kept) —
don't do this silently.
