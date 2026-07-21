# `win-paste` clipboard file materialization

**Date:** 2026-07-21  
**Status:** Approved  
**Related:** `bin/win-paste`, agent workflows that cannot ingest terminal image pastes

## Problem

Terminal agents cannot receive graphics via normal clipboard paste. Tools such as OpenCode accept attachments as filesystem paths or `file://` URIs (and sometimes `@path`). `win-paste` today only emits text (WSLg `wl-paste` or PowerShell `Get-Clipboard`), so an image on the Windows clipboard is unusable in that workflow.

Large text pastes have a related packaging need: materialize clipboard bytes as a private cache file and emit a stable text reference the agent can attach.

## Goals

- Opt-in flags on `win-paste` that materialize clipboard content to a user-private cache file and print a single reference.
- Support image and text/HTML payloads with a clear default when multiple formats are offered.
- Optional `--format` conversion using short type names.
- Dedup by content hash so repeated pastes of the same bytes reuse an existing file.
- Preserve today’s default text-paste behavior when no `--file-*` flag is used.

## Non-goals

- Changing default `win-paste` / `wl-paste` text behavior.
- Explorer file-list / HDROP paste.
- Background cache garbage collection or TTL sweeping.
- Size caps on materialized text (agents may enforce their own limits).
- Broad conversion matrix (PDF, markdown, exotic codecs).
- Wrapping agent-specific syntax beyond `@path` (`--file-atpath`).

## Decisions

| Topic | Choice |
|-------|--------|
| Emit flags | `--file-url`, `--file-path`, `--file-atpath` (exactly one required for materialize mode) |
| Mutual exclusion | Error if more than one `--file-*` emit flag |
| Always materialize | Yes — even short text becomes a cache file when a `--file-*` flag is set |
| Default format pick | Richest available when `--format` omitted: image → html → plain text |
| Conversion flag | `--format <shortname>` (`png`, `jpeg`/`jpg`, `gif`, `webp`, `txt`, `html`) |
| Cache root | `${XDG_CACHE_HOME:-$HOME/.cache}/wslutil/clipboard/` (dir mode `0700`) |
| File mode | `0600` |
| Filename | `clip-<localtime>-<kind>-<shortsum>.<ext>` |
| Timestamp | Local time, `YYYYMMDD-HHMMSS` (not UTC/GMT) |
| Shortsum | First 12 hex chars of SHA-256 of **final written bytes** |
| Kind | `image` \| `html` \| `text` — reflects **written** payload (e.g. HTML→`txt` yields `kind=text`) |
| Extension | From written type; `jpeg`/`jpg` both write `.jpg` |
| Dedup | Before write, find existing `clip-*-<kind>-<shortsum>.<ext>`; reuse first match and skip write |
| `--raw` + `--file-*` | Error |
| Implementation | Extend `bin/win-paste` only (no new top-level command) |

## CLI contract

```text
win-paste --file-url|--file-path|--file-atpath [--format <fmt>]
```

### Stdout (exactly one line of reference, no extra noise)

| Flag | Example |
|------|---------|
| `--file-url` | `file:///home/user/.cache/wslutil/clipboard/clip-20260721-160812-image-a1b2c3d4e5f6.png` |
| `--file-path` | `/home/user/.cache/wslutil/clipboard/clip-20260721-160812-image-a1b2c3d4e5f6.png` |
| `--file-atpath` | `@/home/user/.cache/wslutil/clipboard/clip-20260721-160812-image-a1b2c3d4e5f6.png` |

- Paths are absolute.
- `file://` URLs percent-encode path characters as required.

### `--format` values (v1)

`png` | `jpeg` | `jpg` | `gif` | `webp` | `txt` | `html`

MIME strings are not required in v1 (optional aliases later).

### Errors (stderr + non-zero exit)

- More than one of `--file-url` / `--file-path` / `--file-atpath`
- `--file-*` combined with `--raw`
- Empty clipboard / no usable offer
- `--format` requests a conversion that cannot be performed
- Cache directory cannot be created or written

## Filename examples

```text
clip-20260721-160812-image-a1b2c3d4e5f6.png
clip-20260721-160812-text-9f8e7d6c5b4a.txt
clip-20260721-160812-html-0ead1beefcaf.html
```

Dedup may return an older timestamp in the filename when content already exists; that is intentional.

## Backends

### WSLg path

When `WSL2_GUI_APPS_ENABLED=1` and `/usr/bin/wl-paste` is executable:

- List offers via `wl-paste --list-types` (or `-l`)
- Fetch chosen MIME with `wl-paste -t <mime> -n`
- Apply richness ladder / `--format` the same as the PowerShell path

### PowerShell fallback

- `powershell.exe -NoProfile` to probe text / HTML / image and write bytes
- Same richness ladder and `--format` rules

## Write / conversion policy

| Source | No `--format` | With `--format` |
|--------|---------------|-----------------|
| PNG / JPEG / GIF / WebP | Keep as-is | Convert when requested; v1 must support → `png`; other image targets best-effort or clear error |
| DIB / BMP | → `png` | Honor `--format` |
| `text/html` | → `.html` | `txt` = extract/strip to plain text if straightforward, else error; `html` = as-is |
| Plain text | → `.txt` | `txt` = as-is; `html` = **error** in v1 (no wrap) |

Checksum / shortsum is always over the **bytes actually written** (after conversion).

## Compat

- No `--file-*`: existing behavior unchanged (CR strip by default; `--raw`; wl-paste option passthrough).
- Help text documents the new flags and cache location.

## Testing (BATS, minimal)

- Mutual exclusion of emit flags
- Text materialize + each emit shape (`url` / `path` / `atpath`)
- Dedup: second materialize of identical bytes reuses the existing file
- Unsupported `--format` combo fails non-zero
- Default text paste without `--file-*` still strips trailing CR (regression)

Live image clipboard tests may use mocks/fixtures where the environment cannot supply a real image clipboard.

## Open follow-ups (out of scope)

- MIME aliases for `--format` (`image/png` → `png`)
- `latest` symlink in the cache dir
- Cache GC / size limits
- HDROP / copied Explorer paths
- Richer HTML→text extraction quality
