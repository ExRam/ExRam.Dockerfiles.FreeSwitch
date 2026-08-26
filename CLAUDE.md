# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A Dockerfile build for a custom FreeSwitch image (`ghcr.io/exram/freeswitch`), based on Alpine Linux's
`freeswitch` aport, with a couple of ExRam-specific source patches applied and `fail2ban` baked in. There
is no application source code here — this repo's job is to build and package FreeSwitch, not to write it.

## Repository layout

- `Dockerfile` — multi-stage build. Stage `build` compiles the `freeswitch` and `freeswitch-sample-config`
  Alpine packages from the `aports` submodule using `abuild` (applying the two patches in `patches/` via
  `sed` injection into the APKBUILD `source=` array before building). Stage `freeswitch` installs those
  built `.apk` packages plus `fail2ban` into a fresh `alpine` base image.
- `aports/` — **git submodule** pointing at `https://github.com/ExRam/aports.git` (ExRam's fork of Alpine's
  aports). Only `aports/main/freeswitch/` is actually used by the build; the rest of the submodule tree is
  the full upstream aports mirror and is not relevant to this repo's changes. The FreeSwitch package
  version/config lives in `aports/main/freeswitch/APKBUILD`; do not edit files under `aports/` directly in
  this repo — changes there belong in the `aports` fork/submodule, not here.
- `patches/` — ExRam's own source patches applied on top of upstream FreeSwitch, injected into the abuild
  process at build time (they are not part of the aports submodule):
  - `add-traceparent-to-logs.patch` — adds the `traceparent` channel variable to FreeSwitch's JSON log
    output (`src/switch_log.c`), for distributed tracing correlation.
  - `exram-start-message.patch` — stamps the FreeSwitch startup log line with "ExRam Custom Build" plus
    the image version (`src/switch_core.c`); the version string is templated in via `sed` in the
    Dockerfile using the `version`/`versionHeight`/`alpineVersion` build args.
- `entrypoint.sh` — container entrypoint (`CMD`): starts `fail2ban-server` in the background, then runs
  `freeswitch -nonat` in the foreground.
- `.github/workflows/build.yml` — CI. On push to `main`, computes version numbers from the APKBUILD
  `pkgver`/`pkgrel` and the aports submodule's tag/commit count, builds the multi-stage Dockerfile for
  `linux/amd64` and `linux/arm64`, pushes several version tags to `ghcr.io/exram/freeswitch`, and then
  tags the repo itself via `github-tag-action`. There is no separate test/lint job.

## Working with patches

The patches in `patches/` are unified diffs against the upstream FreeSwitch source tree (the tarball
fetched by `aports/main/freeswitch/APKBUILD`), applied during `abuild`. When modifying or adding a patch:
- Keep the diff format consistent with the existing patches (`diff --git a/... b/...` against `src/*.c`).
- Any new patch file must also be registered in the Dockerfile's `build` stage: copied in with `COPY`, and
  appended to the APKBUILD's `source=` line via the same `sed` pattern used for the existing two patches.

## Building

There is no local build/test/lint tooling beyond Docker itself — the build is only exercised via
`docker build`. Building requires the `aports` submodule to be checked out and the `version`,
`versionHeight`, and `alpineVersion` build args to be supplied (CI derives these from
`aports/main/freeswitch/APKBUILD` and the submodule's git tags; see `build.yml` for the exact derivation
if you need to build/test locally). The full compile is slow (compiling FreeSwitch from source via abuild).
