# Contributing to Tcpreplay

Thanks for considering a contribution. This document is the fast path to a
PR or issue that gets looked at quickly; `docs/HACKING` has the deeper detail
(file layout, coding standards, DLT plugin architecture).

## Before you open something

- **Usage questions** go to the
  [tcpreplay-users mailing list](https://sourceforge.net/p/tcpreplay/mailman/tcpreplay-users/)
  or [Stack Overflow](https://stackoverflow.com/questions/tagged/tcpreplay),
  not GitHub Issues.
- **Suspected security vulnerabilities** go through the
  [security policy](https://github.com/appneta/tcpreplay/security/policy) —
  never a public issue or PR.
- **Search first.** Check open and closed issues/PRs for your topic before
  filing a new one.

## Reporting a bug

Use the bug report form — it asks for the version, exact command line,
expected vs. actual behavior, and reproduction steps, because a report we
can't reproduce usually can't be fixed. If the triggering pcap can't be
shared, describe how to construct an equivalent one, or attach a minimal
capture that isolates just the problem.

## Requesting a feature

Use the feature request form. Describe the problem you're actually trying to
solve, not just the flag you imagine — sometimes there's already a way to do
it, or a better one.

## Contributing code

1. **Build and test locally before opening a PR.**

   ```
   ./autogen.sh && ./configure && make
   cd test && sudo make test
   ```

   (or `cmake -B build && cmake --build build` — see the top of `CLAUDE.md`
   or `README` for the full flag reference either build system supports).
   `sudo make test` needs root and live traffic on a configured NIC; if you
   can't run it, say so in the PR and describe what you tested instead.

2. **Follow the coding standards in `docs/HACKING`**: 4-space indent, no
   tabs; `warnx`/`dbg`/`errx` instead of raw `printf`/`fprintf`;
   `safe_malloc`/`safe_strdup`/`safe_realloc` instead of the raw libc calls;
   `strlcpy`/`strlcat` instead of `strcpy`/`strcat`. Run `clang-format` on
   changed files before committing — `.clang-format` is checked in.

3. **Keep PRs focused.** One fix or one feature per PR. A bug fix doesn't
   need a drive-by refactor of the surrounding code; a large feature is
   easier to review as a series of small PRs than one enormous diff.

4. **Explain the change**, not just what changed but why: what was broken,
   what triggers it, how you verified the fix. "Fixes a bug" with no
   reproduction case or test evidence is not a reviewable PR.

5. **Packet-rewriting logic belongs in `src/tcpedit/`**, not `tcprewrite.c`
   directly — `tcpbridge` and `tcpreplay-edit` depend on the same code path.

6. By submitting a patch you agree it's licensed under the same terms as the
   rest of the project (GPLv3) and that copyright is assigned per
   `docs/HACKING` §0. You'll be credited in `docs/CREDIT`.

### What gets closed without review

- PRs that don't build, or that skip the test evidence above with no
  explanation.
- PRs generated wholesale by an LLM/tool with no indication the author
  understood, ran, or verified the change.
- Unrelated scope creep (formatting-only sweeps, dependency bumps, or
  "cleanup" bundled into an unrelated fix).
- Issues that don't use the report form's fields, or that turn out to be
  usage questions.

None of this is about being unwelcoming — it's what keeps a small maintainer
team able to actually review what comes in. If you're unsure whether
something's in scope, open an issue describing the idea before investing
time in a PR.
