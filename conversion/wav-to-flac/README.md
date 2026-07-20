# wav-to-flac

Verified WAV → FLAC conversion for music libraries. Remuxes sources to clean PCM, encodes with checks, copies tags/cover, and skips (or repairs) existing FLACs safely.

Part of **[audio-utils](../../)** — a collection of audio conversion tools.

## Requirements

- Linux with **GNU find** (`-printf`). On macOS: `brew install findutils` and use `gfind`, or pass directory lists another way.
- `bash` 4+ (associative arrays)
- `flac`
- `ffmpeg` / `ffprobe`
- `flock` (util-linux) — parallel-safe log appends
- `find`, `sha256sum`, `df`, `numfmt`, `nproc` (coreutils)

## Quick start

```bash
# Required for ./convert-all.sh and make find-dirs / clean-tmp
# Prefer XDG config: ~/.config/audio-utils/config (see ../config.example)
# Or: export AUDIO_UTILS_ROOTS="$HOME/Music $HOME/Downloads"
export AUDIO_UTILS_ROOTS="$HOME/Music $HOME/Downloads"

# Preview
./convert-all.sh -n

# Convert (quiet: progress + failures + summary)
./convert-all.sh -q

# Or via make
make dry-run
make convert-quiet
```

Without env roots, pass directories explicitly:

```bash
./find-wav-dirs.sh ~/Music ~/Downloads | ./wav-to-flac.sh -q
./wav-to-flac.sh ~/Music/Artist/Album
```

`WAV2FLAC_ROOTS` is accepted as an alias for `AUDIO_UTILS_ROOTS`.

## Scripts

| Script | Role |
|--------|------|
| `convert-all.sh` | `find-wav-dirs.sh \| wav-to-flac.sh` — pass-through options |
| `find-wav-dirs.sh` | List dirs that contain `.wav` files |
| `wav-to-flac.sh` | Convert / verify / cleanup / retag |
| `lib/` | Modular implementation |
| `Makefile` | `check`, `dry-run`, `convert`, `delete-wavs`, … |

## Usage

```bash
# Explicit directories
./wav-to-flac.sh /path/to/album

# From a list or pipe
./wav-to-flac.sh -f dirs.txt
./find-wav-dirs.sh ~/Music | ./wav-to-flac.sh -q

# Later: delete WAVs that already have valid FLACs
./convert-all.sh -D -n
./convert-all.sh -D

# Re-copy tags/cover onto existing FLACs (no re-encode)
./convert-all.sh -R
```

### Options (`wav-to-flac.sh` / `convert-all.sh`)

| Flag | Description |
|------|-------------|
| `-n` | Dry run |
| `-q` | Quiet (progress + failures + summary) |
| `-v` | Verbose (remux/prep notes, peak scaling, e2e details) |
| `-j N` | Parallel jobs (default: `max(1, nproc/2)`) |
| `-y` | Overwrite FLACs even if `flac -t` passes |
| `-d` | Delete WAV after successful convert |
| `-c` | Replace WAV with clean decode from FLAC |
| `-D` | Cleanup only: delete WAVs that already have a valid sibling FLAC |
| `-R` | Retag only: copy metadata/cover onto existing valid FLACs |
| `-f FILE` | Read directory list from file |
| `-L FILE` | Failure log (default: `$XDG_STATE_HOME/audio-utils/wav-to-flac/failures.log`) |
| `-S FILE` | Success log CSV or `.jsonl` (default: `…/success.csv` in that state dir) |
| `-h` | Help |
| `--version` | Print version |

Exit codes: `0` ok, `1` conversion/preflight failures, `2` usage/config/deps.

## What it does (per file)

1. **Remux** to a clean PCM temp  
   - Float WAV → `pcm_s24le` (scale if peak > 1.0 to avoid clipping; noted with `-v`)  
   - Integer WAV → same codec (endian normalized), strips container junk  
   - Dual remux + hash checks  
2. **Encode** prep → FLAC twice; SHA-256 must match  
3. **Round-trip** decode → re-encode; hashes must match  
4. **Audio MD5** prep == FLAC == decode  
5. **`flac -t`** integrity check  
6. **Tags/cover** copied from the source WAV (audio stream untouched)  
7. Atomic write next to the destination; temps cleaned on EXIT/INT/TERM  

Existing FLACs that pass `flac -t` are **skipped**. Corrupt siblings are **reconverted**.

Progress looks like: `[3/59 elapsed=0:01:12 eta=0:18:40] convert: …`

## Disk space & temps

- Before each directory: requires about **3× the largest WAV** free on that filesystem.  
- Workdirs: `.wav2flac.*` beside the album (atomic `mv` on the same filesystem).  
- If a beside-dest workdir cannot be created, fallback temps go under **`$XDG_RUNTIME_DIR/audio-utils/`** (else `$XDG_CACHE_HOME/audio-utils/runtime/`).  
- Discovery uses **`find -P`** (does not follow symlinks) and **`LC_ALL=C`** sort order.  
- Startup sweeps orphan `.wav2flac.*` under `AUDIO_UTILS_ROOTS` and target dirs.  
- Ctrl-C / EXIT also cleans registered workdirs.  
- State/log dirs are created lazily (not on `-h` / `-n` / `--version`).

## Logs

Defaults follow the [XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/latest/) layout:

| Kind | Location |
|------|----------|
| Config | `${XDG_CONFIG_HOME:-~/.config}/audio-utils/config` |
| Failure / success logs | `${XDG_STATE_HOME:-~/.local/state}/audio-utils/wav-to-flac/` (mode `600`) |
| Runtime temps (status, lists, registry) | `$XDG_RUNTIME_DIR/audio-utils/` (else cache `runtime/`) |

- **Failures** (`-L`): wide TSV (or `.jsonl`) with timestamp, path, reason, detail, codec, bytes, samples, progress; deleted if header-only at end of run  
  - Stderr always prints a multi-line `FAIL […]` block (even under `-q`) with probe fields and tool stderr snippets  
- **Successes** (`-S`): CSV by default, or JSON Lines if the path ends in `.jsonl`  
  - CSV columns: `timestamp,wav,flac,audio_md5,flac_sha256,codec,bytes,samples,notes`
- Both logs use **`flock`** so parallel (`-j`) appends stay intact  
- Override anytime: `-L /path/fail.tsv -S ./run.jsonl` (relative paths = cwd)

```bash
./convert-all.sh -q -S "$XDG_STATE_HOME/audio-utils/wav-to-flac/success.jsonl"
# or a cwd override:
./convert-all.sh -q -S ./run.jsonl
```

`make clean` removes both legacy cwd logs and the XDG state logs for this tool.

## Make targets

```bash
make check              # shellcheck -x -a
make find-dirs          # list dirs with WAVs (needs AUDIO_UTILS_ROOTS or ROOTS=…)

make dry-run            # preview convert (-n)
make convert            # convert all
make convert-quiet      # convert (-q)
make convert-verbose    # convert (-v)
make convert-delete     # convert then delete WAVs (-d)
make convert-clean      # convert then replace WAVs with FLAC decode (-c)

make delete-wavs-dry    # preview delete WAVs that already have FLACs (-D -n)
make delete-wavs        # delete WAVs that already have valid FLACs (-D)

make retag-dry          # preview retag (-R -n)
make retag              # retag existing FLACs from WAVs (-R)

make clean              # remove local success/failure logs
make clean-tmp          # remove orphan .wav2flac.* under ROOTS / AUDIO_UTILS_ROOTS
```

Pass extra flags with `ARGS`:

```bash
make convert-quiet ARGS='-j 4 -S run.jsonl'
make delete-wavs ARGS='-q'
make clean-tmp ROOTS="$HOME/Music $HOME/Downloads"
```

## Layout

```
wav-to-flac.sh       CLI + directory driver
convert-all.sh       Discover + convert wrapper
find-wav-dirs.sh     WAV discovery (wraps ../../lib/find-audio-dirs.sh)
Makefile
README.md
.shellcheckrc
lib/                 Tool-specific pipeline
  load.sh            Shared ../../lib + local modules
  success_log.sh     CSV/JSONL success schema
  prepare.sh         Clean remux / float→int prep
  encode.sh          flac encode + tag/cover
  convert.sh         Per-file pipeline + retag
  cleanup.sh         -D delete-existing mode
  worker.sh          Parallel worker (status files + OK/FAIL)
```

Shared infra lives in [`../../lib/`](../../lib/) (logging, progress, tmpdirs, probes, disk, roots, find-audio-dirs).

## Notes

- FLAC is integer-only. Float masters are quantized to 24-bit (matches float32 mantissa). Peak scaling above 0 dBFS is applied when needed so conversion does not clip (details with `-v`).  
- `-d` and `-c` are mutually exclusive (`-d` wins). `-D` and `-R` are specialized modes that ignore conflicting flags.  
- Parallel job counts come from per-job status files (not only stdout), so totals stay accurate under `-j`.  
- Requires `flac`, `ffmpeg`, `ffprobe`, and `flock` (checked at startup).

## License

MIT — see [../../LICENSE](../../LICENSE).
