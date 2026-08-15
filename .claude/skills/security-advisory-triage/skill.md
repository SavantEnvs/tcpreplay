---
name: Security Advisory Triage
description: Move a GitHub Security Advisory through accept, fix, and publish for this repo. Use when the user shares a GHSA URL, asks to triage/accept/publish an advisory, or asks whether new advisories apply to the current code.
---

## Security Advisory Triage

Worked example: three advisories (GHSA-pmmx-m8p5-969j, GHSA-4hqm-8v2c-9pwj,
GHSA-p3f2-88rg-9mch) went through this exact flow on 2026-08-15.

### 1. Check if it applies

Don't assume a reported advisory still reproduces — verify against the
current code before doing anything else:

```
gh api repos/appneta/tcpreplay/security-advisories/<GHSA-id>
```

Read the description for the exact file/function/line cited, then check
that code as it exists now (`Read`, not memory). A vulnerable-version range
like `<= 4.5.1` doesn't mean it's still broken on `master` — confirm the
specific bug is still there before treating it as real work.

### 2. Decide: fix in the open, or fix privately first

- **DoS-only, memory leak, or anything not exploitable beyond a crash**: fix
  in the open, same as a normal bug — branch, PR, merge.
- **Memory corruption reachable by attacker-controlled input (heap/stack
  overflow, UAF, OOB write)**: this needs private handling before anything
  public. On the advisory page, the maintainer clicks **Accept and open as
  draft security advisory** — this is a UI action, not something to attempt
  via API (there's no reliable "accept" endpoint, and getting it wrong risks
  not actually keeping the fix private). Ask the user to click it and hand
  you the resulting private fork's URL.
- Once a private fork exists: clone it, branch, fix, verify (ideally
  reproduce the PoC before/after — see below), push and open a PR *within
  the private fork*, not the public repo. Only cherry-pick the fix commit
  onto the public release branch after the user says the private fork PR is
  merged.

### 3. Verify the fix actually works

Reproduce the reported crash before the fix and confirm it's gone after,
where the advisory includes a PoC. This caught real details worth putting
in the PR description (e.g. the radiotap fix's exact byte-overflow amount
matched the advisory's own numbers once verified). Don't just trust that the
code change "looks right" — these are exploitability claims, worth the extra
few minutes.

### 4. Publishing the advisory

Once the fix is merged (public or cherry-picked from private), the advisory
record itself still needs three things set, in this order:

1. **`patched_versions`** — set to the version this ships in, even if
   unreleased/untagged yet:
   ```
   gh api repos/.../security-advisories/<id> -X PATCH --input payload.json
   ```
   (PATCH needs the full `vulnerabilities[]` array reposted with
   `ecosystem: "other"` for a C project — GitHub's ecosystem enum doesn't
   have a "c" option, even though a resolved advisory may display one.)

2. **CVE request** — ask the user; don't assume. Severity matters here:
   higher-CVSS/RCE-potential findings usually warrant one, lower-severity
   DoS findings are more of a judgment call. If the user doesn't answer or
   dismisses the question, proceed without requesting one rather than
   blocking — it can be requested later:
   ```
   gh api repos/.../security-advisories/<id>/cve -X POST
   ```

3. **Publish**:
   ```
   gh api repos/.../security-advisories/<id> -X PATCH -f state=published
   ```
   This works directly from `triage` state — no need to route through
   `draft` first for advisories that were never accepted into a private
   fork.

### 5. Credit

Add the reporter to `docs/CREDIT`, grouped by person if they filed more than
one advisory. Match the file's existing format (name, GitHub handle, bullet
list of what they found with GHSA links).
