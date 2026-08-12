# bluray-to-flac

Extract every audio stream from authored Blu-ray titles or decrypted media and
archive it as a verified FLAC.

## Inputs

- A `BDMV` directory, its parent disc directory, or its `STREAM` directory.
- A Blu-ray device such as `/dev/sr0`.
- A Blu-ray `.iso` image.
- A standalone decrypted `.m2ts`, `.mkv`, `.mka`, `.mp4`, or `.ts` file.
- A directory containing supported decrypted media, searched up to three
  levels deep.

Authored BDMV trees, devices, and ISO images require **MakeMKV** (`makemkvcon`)
to resolve playlists and perform any decryption it supports. Standalone media
only requires `ffmpeg`, `ffprobe`, `flac`, and `metaflac` and must already be
readable. This project does not ship AACS keys, BD+ dumps, or MakeMKV.

Raw `BDMV/STREAM/*.m2ts` clips are never treated as titles. Blu-ray playlists
can join, trim, reuse, or branch clips, so clip-by-clip extraction can duplicate
or incorrectly segment a program.

## Usage

```bash
# Authored disc tree, ISO, or decrypted media
bluray-to-flac.sh /path/to/disc
bluray-to-flac.sh /path/to/disc.iso
bluray-to-flac.sh /path/to/title.mkv

# Optical device
bluray-to-flac.sh -D /dev/sr0

# Select one MakeMKV title, or discard titles shorter than five minutes
bluray-to-flac.sh --title 3 /path/to/disc
bluray-to-flac.sh --title all --minlength 300 /path/to/disc

# Preview exact outputs for standalone media
bluray-to-flac.sh -n /path/to/decrypted-media

# Keep reusable MakeMKV title MKVs and split chapter tracks
bluray-to-flac.sh --stage-dir /archive/staging --split-chapters /path/to/disc

# Verify an existing archive without reading the source again
bluray-to-flac.sh --verify-archive /archive/disc/flac

# Fully decode-audit it, or create a recoverable signed package
bluray-to-flac.sh --audit-archive /archive/disc/flac
bluray-to-flac.sh --preserve-streams --sign-key /keys/archive.key \
  --par2-percent 10 --seal /path/to/disc
```

Options:

| Option | Meaning |
|---|---|
| `-D DEVICE` | Read a Blu-ray device; also works through `AUDIO_UTILS_BD_DEVICE`. |
| `--title N\|all` | Extract one MakeMKV title number or all titles (default: `all`). |
| `--minlength SEC` | Ignore shorter authored titles (default: `0`, which keeps all). |
| `--stage-dir DIR` | Keep and safely reuse readable MakeMKV title MKVs under `DIR`. |
| `--split-chapters` | Also create verified per-chapter FLAC tracks. |
| `--allow-float-reduction` | Explicitly permit verified float PCM to 24-bit conversion. |
| `--verify-archive DIR` | Validate `DIR/SHA256SUMS` and exit. |
| `--audit-archive DIR` | Verify the package, fully decode every FLAC, compare its MD5, and verify PAR2 data. |
| `--preserve-streams` | Remux each original compressed/lossless audio bitstream to `<flac>.source.mka`. |
| `--sign-key FILE` | Sign `SHA256SUMS` with a minisign secret key. |
| `--par2-percent N` | Add `N` percent PAR2 recovery data (`0`–`100`). |
| `--seal` | Flush the completed package and make integrity/provenance metadata read-only. |
| `-f FILE` | Read newline-delimited input paths from a file. |
| `--dirs0` | Read NUL-delimited input paths from stdin. |
| `-L FILE` / `-S FILE` | Override failure and success log paths. |
| `-n` | Dry run. Standalone media lists exact output paths; authored input verifies that MakeMKV is available. |
| `-y` | Replace an existing output that is stale or otherwise does not match its source audio. |
| `-q` / `-v` | Quiet or verbose output. |
| `-j N` | Accepted for CLI parity; extraction remains serial per title. |
| `-h`, `--help`, `--version` | Show help or version information. |

`AUDIO_UTILS_BD_TITLE` and `AUDIO_UTILS_BD_MIN_LENGTH` set the corresponding
defaults. `AUDIO_UTILS_MAKEMKV` may point to a MakeMKV executable. For device
input, `AUDIO_UTILS_BD_DISC_ID` may provide a stable output identifier; it must
start with an alphanumeric character and contain only alphanumerics, `.`, `_`,
or `-`.

`AUDIO_UTILS_BD_STAGE_DIR`, `AUDIO_UTILS_BD_SPLIT_CHAPTERS`,
`AUDIO_UTILS_BD_ALLOW_FLOAT`, `AUDIO_UTILS_BD_PRESERVE_STREAMS`,
`AUDIO_UTILS_BD_SIGN_KEY`, `AUDIO_UTILS_BD_PAR2_PERCENT`, and
`AUDIO_UTILS_BD_SEAL` provide environment equivalents. Set
`AUDIO_UTILS_BD_SIGN_PUBKEY` when verifying a minisign signature without a
matching public key embedded in the normal minisign configuration.

`find-bdmv-dirs.sh` discovers BDMV directories below explicit roots (or the
configured roots), and `convert-all.sh` discovers and converts them. Both
support the shared discovery conventions, including NUL-delimited paths.

## Outputs and verification

Each audio stream becomes `<source-name>.a<N>.flac`; retaining the container
extension prevents collisions such as `title.mkv.a0.flac` versus
`title.m2ts.a0.flac`. Output locations are:

- BDMV input: `flac/` beside the `BDMV/` directory.
- Standalone file: beside the source file.
- Media directory: its `flac/` subdirectory, with relative subdirectories
  mirrored.
- Device: `./bluray-rip/disc-<id>/`.
- ISO image: `<image-name>.flac/` beside the ISO.

Device IDs normally derive from a constrained subset of MakeMKV disc metadata,
title durations, and title sizes, preventing outputs from different discs in
the same drive from colliding. `AUDIO_UTILS_BD_DISC_ID` provides an explicit
stable override when metadata differs across systems. MakeMKV input is
also inventoried before extraction; if it creates fewer MKVs than the selected
authored-title count, the run fails.

FLAC tags retain the source codec, profile, language, stream title, and channel
layout when available. `SOURCE_AUDIO_MD5` records the decoded stream audio and
`SOURCE_STREAM` records its audio-stream number. An existing FLAC is skipped
only when it is valid, its decoded MD5 matches that source-audio MD5, and its
stream tag matches; otherwise the command fails until `-y` is supplied. This
audio-based identity remains stable when only container metadata changes.

Every output also records source class, channels, sample rate, input precision,
and output precision. Lossy sources and object-audio loss are explicit. Integer
32-bit PCM remains 32-bit when the installed FLAC encoder supports it. Float
PCM fails closed unless `--allow-float-reduction` authorizes the shared,
verified 24-bit preparation path; affected outputs carry `PRECISION_REDUCED=1`.

For titles with chapters, the converter writes `.ffmetadata`, `.chapters.json`,
and CUE sidecars. CUE is omitted only when the FLAC filename contains a newline,
which CUE cannot represent safely. `--split-chapters` additionally creates a
verified `<name>.chapters/` directory of per-chapter FLAC tracks. Their exact
sample total and concatenated decoded MD5 must reproduce the covered parent
region before the archive can complete.

Each archive contains:

- `provenance/archive-manifest.jsonl` with input/title/stream identities,
  decoded MD5, file SHA-256, sample count, rate, channels, and precision;
- `provenance/tool-versions.txt`;
- persisted MakeMKV inventory, log, and classified warning files when used;
- normalized MakeMKV title and message TSVs when MakeMKV was used;
- `SHA256SUMS`, generated and immediately verified only after a successful run;
- `ARCHIVE_COMPLETE.json`, written last after metadata publication, checksums,
  optional signing/recovery data, and a filesystem flush. It carries a stable
  package identifier and declares whether signatures, PAR2, preserved streams,
  and sealing are required; later verification fails if declared artifacts are
  missing or unexpected artifacts contradict that policy.

Checksum entries are restricted to relative paths inside the package. An absent
or malformed completion marker means the package is incomplete, even if some
outputs exist. Session provenance is published atomically and aborted sessions
do not enter the permanent manifest. Use `--verify-archive DIR` for quick file
integrity checks and `--audit-archive DIR` for a periodic full decode audit.
`--stage-dir DIR` retains MakeMKV title MKVs under a source/disc-specific
directory; `STAGE_SHA256SUMS` must verify before a retry can reuse them.

`--preserve-streams` retains the original codec payloads independently of the
FLAC representation, which is especially useful for TrueHD/Atmos, DTS-HD/DTS:X,
and lossy sources. `--sign-key` adds authenticity, `--par2-percent` adds local
damage recovery, and `--seal` makes package metadata read-only after flushing
it. These controls complement backups; PAR2 and read-only permissions are not
substitutes for independent copies.

Lossy codecs are marked `LOSSY_SOURCE=1` and reported. Dolby Atmos and DTS:X
object data cannot be represented in FLAC. Extraction uses strict decoder error
handling, rejects audio materially shorter than its reported source duration,
performs the shared verified FLAC encode, and tests the final tagged file before
installing it atomically. Source duration falls back through stream duration,
Matroska's `DURATION` tag, and container duration. A conservative free-space
preflight runs before extraction. Media-directory and MakeMKV runs fail if any
candidate output is unreadable rather than silently returning partial success.

Exit status is `0` for success, `1` for an extraction or verification failure,
and `2` for usage or dependency errors. Progress and diagnostics go to stderr;
success and failure logs use the normal audio-utils state directory unless
overridden.

See [disc and MakeMKV notes](../../docs/discs.md),
[requirements](../../docs/requirements.md), and
[streaming scope](../../docs/streaming.md).

Part of [audio-utils](../../).
