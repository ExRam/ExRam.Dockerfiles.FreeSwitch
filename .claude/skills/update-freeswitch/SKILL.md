---
name: update-freeswitch
description: Use when a new FreeSwitch release is out and the aports submodule's APKBUILD needs bumping to it. Triggers - "update freeswitch", "bump freeswitch", "new freeswitch release", "freeswitch 1.x.x". Captures the procedure for updating pkgver/pkgrel, checking upstream release notes for build/dependency-breaking changes, and adjusting APKBUILD/modules.conf/local patches to match, on a dedicated aports branch.
argument-hint: "<target-freeswitch-version>, e.g. 1.12.0"
---

# Bumping FreeSwitch in the aports submodule

This repo builds `ghcr.io/exram/freeswitch` from the `freeswitch` Alpine package defined in
`aports/main/freeswitch/APKBUILD` (a git submodule, ExRam's fork of Alpine's aports, at
`https://github.com/ExRam/aports.git`). FreeSwitch releases aren't just a `pkgver` bump: upstream regularly
migrates build dependencies (e.g. the PCRE -> PCRE2 move in 1.11.0) and removes/renames modules, and this
package's local source patches (`aports/main/freeswitch/*.patch`) and this repo's own `patches/*.patch`
patch specific line numbers/context in FreeSwitch's C sources, which shift or disappear across releases.
Treat every bump as requiring real verification, not a blind `sed`.

Target version for this run: **$ARGUMENTS** (e.g. `1.12.0`). If not given, ask the user which version to
target.

## 1. Establish the starting point

```sh
grep -E "^pkgver=|^pkgrel=" aports/main/freeswitch/APKBUILD
git -C aports status                       # confirm clean, note current tag/branch (e.g. detached at vX.Y.Z)
git -C aports log --oneline -10 -- main/freeswitch/APKBUILD   # confirm no one already bumped past the current pkgver
```

Also check both `origin` (the ExRam fork) and `upstream` (real Alpine aports) for whether this exact bump
already happened somewhere and could be cherry-picked instead of redone from scratch:

```sh
git -C aports log --oneline --all -- main/freeswitch/APKBUILD | head -30
```

## 2. Look up the target release's notes

```sh
gh api repos/signalwire/freeswitch/releases/tags/v$ARGUMENTS
```

Read the `body` field in full (do not trust a summarized/paraphrased version of a GitHub releases *page* —
fetch the raw API object and read the actual release notes text). Look specifically for:

- Build-system / dependency version changes (new `PKG_CHECK_MODULES` minimums, library migrations)
- Removed or renamed modules ("Remove from tree")
- Anything that touches files this package's local patches target

Cross-check the `published_at` date is sane (a suspiciously "too new" or "too old" release for the tag
should raise doubt — verify via the API object, not a scraped page, since scraped release pages can return
stale or wrong content).

## 3. Diff configure.ac and the module list between the current and target tag

```sh
curl -s "https://raw.githubusercontent.com/signalwire/freeswitch/v<current>/configure.ac" -o /tmp/configure_old.ac
curl -s "https://raw.githubusercontent.com/signalwire/freeswitch/v$ARGUMENTS/configure.ac" -o /tmp/configure_new.ac
diff /tmp/configure_old.ac /tmp/configure_new.ac | grep -iE "PKG_CHECK_MODULES|AC_CHECK_LIB|>=|require"

curl -s "https://raw.githubusercontent.com/signalwire/freeswitch/v<current>/build/modules.conf.in" -o /tmp/mods_old.conf
curl -s "https://raw.githubusercontent.com/signalwire/freeswitch/v$ARGUMENTS/build/modules.conf.in" -o /tmp/mods_new.conf
diff /tmp/mods_old.conf /tmp/mods_new.conf
```

Any `PKG_CHECK_MODULES`/`AC_CHECK_LIB` line that changed a required package name or minimum version needs
its `makedepends` entry checked against what Alpine's repo actually provides
(`https://pkgs.alpinelinux.org/package/v<alpine-version>/main/x86_64/<pkg>` — confirm the package exists and
its `.pc` file matches what `configure.ac` looks for).

For modules: cross-check the **actually enabled** lines in this repo's own
`aports/main/freeswitch/modules.conf` (`grep -vE '^\s*#|^\s*$' aports/main/freeswitch/modules.conf`)
against `src/mod/*/` in the target tag via `gh api repos/signalwire/freeswitch/contents/src/mod/<category>?ref=v$ARGUMENTS --jq '.[].name'`.
Any enabled module whose directory is now missing must be disabled/removed:
- from `modules.conf` (comment it out, matching the file's existing convention for unavailable modules)
- from `APKBUILD`'s `makedepends`, if it had a dependency used by no other enabled module
- from `APKBUILD`'s `subpackages=`/any `_mv_mod` subpackage function that packaged it (e.g. the `sangoma()`
  function moved `mod_sangoma_codec.so` into `freeswitch-sangoma` — removing the module without removing
  the subpackage function breaks `package()`)

State plainly in the eventual commit if a dropped module is a real behavior change (lost functionality),
not just a build-system cleanup — a reviewer should not have to infer that from a modules.conf diff alone.

## 4. Verify each local patch against the real target source

Download the actual release tarball referenced by `APKBUILD`'s `source=` (not GitHub's tag archive — it's a
different artifact and won't match what `abuild` actually fetches), matching the filename pattern already
in `APKBUILD` (note: FreeSwitch release tarballs have historically used a literal trailing `.` before
`-release`, e.g. `freeswitch-1.11.0.-release.tar.xz` — preserve whatever pattern `source=`/`builddir=`
already use, driven by `$pkgver`):

```sh
curl -sL -o freeswitch-$ARGUMENTS.-release.tar.xz "https://files.freeswitch.org/freeswitch-releases/freeswitch-$ARGUMENTS.-release.tar.xz"
sha512sum freeswitch-$ARGUMENTS.-release.tar.xz     # this becomes the new sha512sums entry
tar xf freeswitch-$ARGUMENTS.-release.tar.xz
```

For every `*.patch` file in `aports/main/freeswitch/` AND this repo's own `patches/*.patch` (the two ExRam
patches injected by the Dockerfile via `sed` into the APKBUILD `source=` array — check their target files,
`src/switch_log.c` and `src/switch_core.c`, directly too):

```sh
patch -p1 --dry-run < <patch-file>   # run from inside the extracted freeswitch-$ARGUMENTS.-release/ tree
```

For each patch:
- **Applies cleanly (possibly with a line-offset)** -> no change needed.
- **"Reversed (or previously applied) patch detected"** -> upstream already shipped an equivalent fix; that
  hunk is now redundant. If the patch has other hunks that still apply, trim only the redundant hunk(s) and
  keep the rest — don't drop a whole multi-hunk patch file just because one hunk is now upstream.
- **"FAILED" with no "previously applied" note** -> the surrounding code changed for some other reason.
  Read the current upstream source at that location and either rewrite the hunk to match, or — if it's not
  obviously safe to guess the right fix — **stop and check back with the user** rather than forcing it.

Recompute `sha512sums` for every file you actually modified (`sha512sum <file>`) and update the
corresponding line in `APKBUILD`'s `sha512sums=` block. Leave sha512sums for untouched files alone — verify
with a final full `sha512sum` pass that every entry still matches its file on disk.

## 5. Branch and commit

```sh
git -C aports checkout -b freeswitch-$ARGUMENTS
```

Set `pkgver=$ARGUMENTS` and **`pkgrel=0`** — this package resets `pkgrel` to `0` on every `pkgver` bump
(verified against its own history, e.g. commit `7dd1248ef58`: `1.10.11`->`1.10.12` reset `pkgrel=2`->`0`).
Don't guess a different convention; confirm from `git log` for this exact APKBUILD if in doubt.

Commit in small, separately-reviewable batches — one logical change per commit (e.g. the version+checksum
bump; a dependency swap; module removals; each patch file's rework) — **not** one giant diff. Every commit
message needs an extensive body, not just a one-line summary + link, because these commits may end up in a
PR read by people unfamiliar with this repo or its author:

- **What** changed, precisely.
- **Why** — cite the specific evidence (a release-note line, a `configure.ac` diff, a `patch --dry-run`
  result, a `gh api .../contents/...` listing) rather than asserting it.
- Any **caveat** — a real behavior change, an assumption made, anything a reviewer should sanity-check.

Do not push to `origin` (the ExRam fork) without asking the user first, even if this skill is run
end-to-end without interruption elsewhere.

## 6. Run a real build if a container tool is available

`patch --dry-run` and hand-computed `sha512sum`s only catch drift in the files this skill already knows to
check — they cannot catch a real `abuild`/compiler failure. Check `which podman docker` first; if either is
present, actually run the build rather than stopping at dry-run verification:

```sh
podman build --build-arg version=$ARGUMENTS-r0 --build-arg versionHeight=0 --build-arg alpineVersion=<current-alpine-tag> . 2>&1 | tee /tmp/build.log
```

(`versionHeight`/`alpineVersion` don't affect whether it builds — any values work for a local check. The
`version` build-arg must be the full `<pkgver>-r<pkgrel>` string, e.g. `1.11.0-r0` — the Dockerfile's final
stage does `apk add freeswitch=$version`, which needs an exact apk version match; CI computes this
automatically but a manual invocation must supply it, otherwise you'll see `unable to select packages: ...
breaks: world[freeswitch=<bare-pkgver>]` on an otherwise-successful build, which is a usage mistake, not a
real bug.) This is a genuine `abuild -r` compile — slow, run it with a background/backgrounded shell and a
generous timeout rather than blocking, and use `tee` (or `set -o pipefail`) so a real failure isn't hidden
by a piped command's own exit code.

If it fails inside the `abuild -r` step (not the final `apk add`), read the actual error — don't stop at
the last "Error: building at STEP ..." wrapper line, which just names the whole `RUN` command; the real
cause is earlier in the log, often followed by cascading "Purging ..." cleanup output that pushes it out of
a short `tail`. Grep for `>>> ERROR:` specifically.

**Known recurring failure mode to check for:** if the build fails with `>>> ERROR: freeswitch: prepare
failed` right after `autoreconf` completes, with no compiler error in between, suspect Alpine `abuild`'s
`update_config_sub()` helper (`/usr/bin/abuild`, runs under `ash -e`) — its exit status is unreliable
(returns 1 whenever nothing needed updating, due to running the literal string `"false"` as its last
command). Whether `aports/main/freeswitch/APKBUILD`'s `prepare()` should call it at all depends on whether
this release's bundled `config.sub` files (`find . -name config.sub` inside the extracted, unpatched
tarball, typically the top-level one plus one in each vendored sub-library like `apr`/`srtp`) already
recognize `loongarch64-alpine-linux-musl` (test each with `./config.sub loongarch64-alpine-linux-musl`).
If all of them already do, the call has nothing to do and will always fail — remove it from `prepare()`.
If at least one doesn't, keep the call (it'll actually refresh that file). **Never add a guard like
`update_config_sub || true`** — only ~108/1660 `main/` aports packages call `update_config_sub` at all, and
every one of them calls it bare with no exit-code handling; add-or-remove-the-call is the convention-
matching fix, not guarding it.

If a real fix is needed (in `aports/main/freeswitch/` or this repo's `Dockerfile`/`patches/`), make it as
its own small, separately-committed, extensively-documented commit — same conventions as step 5 — and
re-run the build to confirm before moving on.

If no container tool is available in this environment, say so explicitly when reporting back: a real build
via CI or a machine with `podman`/`docker` is still required before the branch is production-ready. Neither
`Dockerfile` nor `.github/workflows/build.yml` normally need changes for a version bump — both derive
`pkgver`/`pkgrel` by grepping the APKBUILD at build time — but double check that's still true if this
skill's target release notes mention anything unusual (e.g. a new required build arg).
