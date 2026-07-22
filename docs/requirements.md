# Requirements

**Platform:** Linux with **GNU** userland (`coreutils`, `findutils`, `util-linux`). Not macOS, BSD, Windows, BusyBox, or Alpine/musl.

**Core (all tools):** `bash` **4.3+**, `flac`, `ffmpeg`/`ffprobe`, `flock`, GNU `find` (`-printf`), coreutils (`sha256sum`, `stat -c`, `df --output`, `date -Iseconds`, …).

Override the find binary if needed: `AUDIO_UTILS_FIND=gfind` (must still support GNU `-printf`).

## Core binaries → packages

| Binary / need | Arch / CachyOS | Debian / Ubuntu | Fedora |
|---------------|----------------|-----------------|--------|
| `bash` (≥ 4.3) | `bash` | `bash` | `bash` |
| `flac` / `metaflac` | `flac` | `flac` | `flac` |
| `ffmpeg` / `ffprobe` | `ffmpeg` | `ffmpeg` | `ffmpeg` (**RPM Fusion**) |
| `flock` | `util-linux` | `util-linux` | `util-linux` |
| GNU `find` (`-printf`) | `findutils` | `findutils` | `findutils` |
| `iconv` | **`glibc`** (base; not a separate package) | **`libc-bin`** | **`glibc-common`** |
| `sha256sum` / `md5sum` / `nproc` / `numfmt` | `coreutils` | `coreutils` | `coreutils` |
| `shellcheck` (dev / `make check`) | `shellcheck` | `shellcheck` | `ShellCheck` |

`metaflac` ships in the same package as `flac`. `ffprobe` ships with `ffmpeg`. `iconv` is part of the C library package on glibc systems — do **not** install `libiconv` on Arch unless you know you need it.

On Fedora, enable [RPM Fusion](https://rpmfusion.org/) before installing `ffmpeg` and most disc CSS/AACS packages.

## Optional binaries → packages

| Binary / need | Arch / CachyOS | Debian / Ubuntu | Fedora |
|---------------|----------------|-----------------|--------|
| `fpcalc` (chromaprint) | `chromaprint` | `libchromaprint-tools` | `chromaprint` (RPM Fusion) |
| `mpcenc` / `mpcdec` | `musepack-tools` | `musepack-tools` | `musepack-tools` |
| `mac` (Monkey’s Audio encoder) | build via `scripts/ape-codec.sh` | same | same |
| `bpm` (bpm-tools) | `bpm-tools` | `bpm-tools` | `bpm-tools` |
| `aubio` (audio-bpm fallback) | `aubio` | `aubio-tools` | `aubio-tools` |
| `keyfinder-cli` | AUR / `scripts/keyfinder-cli.sh` | same (not in apt) | same |
| `rsgain` (preferred ReplayGain) | AUR / chaotic-aur | `rsgain` | COPR / third-party (or use `loudgain`) |
| `loudgain` (ReplayGain fallback) | AUR | `loudgain` | check COPR / third-party |
| `dvdbackup` | `dvdbackup` | `dvdbackup` | `dvdbackup` |
| `libdvdcss` | `libdvdcss` | `libdvdcss2` | `libdvdcss` (RPM Fusion) |
| `libbluray` | `libbluray` | `libbluray2` | `libbluray` |
| `libaacs` | `libaacs` | `libaacs0` | `libaacs` |
| `libbdplus` | often AUR | `libbdplus0` | check RPM Fusion / COPR |
| `cdparanoia` | `cdparanoia` | `cdparanoia` | `cdparanoia` |
| `sox` | `sox` | `sox` | `sox` |
| `mediainfo` | `mediainfo` | `mediainfo` | `mediainfo` |
| `makemkvcon` | often AUR (`makemkv`) | third-party | third-party |
| `wine` (Takc `.exe`) | `wine` | `wine` | `wine` |

## Tool extras

| Tool / feature | Extra dependency |
|----------------|------------------|
| flac-to-mp3 | ffmpeg `libmp3lame` |
| flac-to-opus | ffmpeg `libopus` |
| flac-to-aac | ffmpeg native **`aac`** encoder |
| flac-to-vorbis | ffmpeg `libvorbis` |
| flac-to-wma | ffmpeg `wmav2` |
| flac-to-speex | ffmpeg `libspeex` |
| flac-to-mpc | **mpcenc** + **mpcdec** (`musepack-tools`) |
| flac-to-alac / alac-to-flac | ffmpeg `alac` |
| flac-to-wv / wv-to-flac | ffmpeg `wavpack` |
| flac-to-ape | **`mac`** (Monkey’s Audio; ffmpeg has **no** APE encoder — decode-only). Install via `scripts/ape-codec.sh` or set `AUDIO_UTILS_MAC` |
| ape-to-flac | ffmpeg ape **decoder** (usually present) |
| flac-to-tta / tta-to-flac | ffmpeg `tta` |
| shn-to-flac | ffmpeg Shorten **decoder** (no encoder) |
| lossy-to-flac | core set (decodes mp3/aac/opus/vorbis/wma/mpc/**speex**; `.ogg`/`.oga`; skips ALAC) |
| caf-to-flac / flac-to-caf | core set (CAF mux/demux) |
| dsf-to-flac | ffmpeg DSF demuxer; optional **sox** for DFF |
| flac-to-tak | Official **Takc** (+ Wine if `.exe`); see [tak.md](tak.md) |
| tak-to-flac | ffmpeg TAK decoder and/or Takc |
| dvd-to-flac | **libdvdcss**; optional `dvdbackup` |
| bluray-to-flac | **libbluray** + **libaacs** (+ operator `KEYDB.cfg`); optional **libbdplus**, **MakeMKV** (`AUDIO_UTILS_MAKEMKV`); or already-decrypted M2TS/MKV |
| cdda-to-flac | **cdparanoia** (AccurateRip / MusicBrainz workflows are external — not wired here) |
| cue-to-flac / streams-to-flac / remux-to-flac | core set only |
| wav-to-aiff / aiff-to-wav / flac-to-wav / flac-to-aiff / flac-to-caf | core set (PCM remux) |
| flac-verify | core `flac` + `flock`; `-M` needs `ffmpeg`/`ffprobe`/`metaflac` |
| flac-replaygain | `metaflac` + **rsgain** (preferred) or **loudgain** |
| flac-artwork | `metaflac` |
| flac-audit | `metaflac` |
| flac-authenticity | `ffmpeg`/`ffprobe`, `metaflac`, `od`, `awk`; optional **`sox`** (`-p` spectrograms), **`mediainfo`** (notes) |
| flac-tags | `metaflac` |
| flac-dupes | `metaflac`; `-M` needs `ffmpeg`; `--fingerprint` needs **fpcalc** (chromaprint) |
| flac-optimize | `flac`, `metaflac`, `ffmpeg`/`ffprobe` |
| flac-rename | `metaflac` |
| flac-cue-export | `flac`, `metaflac`, `ffmpeg`/`ffprobe` |
| flac-strip | `metaflac` |
| flac-inventory | `metaflac`, `ffmpeg`/`ffprobe` |
| flac-resample | `flac`, `metaflac`, `ffmpeg`/`ffprobe` |
| audio-replaygain | **rsgain** or **loudgain**, `ffmpeg`/`ffprobe` |
| audio-tags | `ffmpeg`/`ffprobe`; `metaflac` for FLAC |
| audio-bpm | **bpm** (bpm-tools, preferred) or **aubio**; `ffmpeg`/`ffprobe`; `metaflac` for FLAC |
| audio-key | **keyfinder-cli**; `ffmpeg`/`ffprobe`; `metaflac` for FLAC |
| audio-dupes | **fpcalc** (default); `-M` needs `ffmpeg` |
| audio-artwork | `ffmpeg`/`ffprobe`; `metaflac` optional for FLAC |
| library-sync | `flac` |
| tree-diff | coreutils; `--hash` needs `sha256sum` |
| hash-verify | `sha256sum` or `md5sum` |
| pcm-cleanup | `flac`, `ffmpeg`/`ffprobe` |
| cue-audit | shared `lib/cue.sh`; optional `iconv` for UTF-8 |
| silence-detect | `ffmpeg`/`ffprobe`, `awk` |
| disc-inventory | core set |
| lossy-audit | `ffmpeg`/`ffprobe` |
| playlist-audit | `lib/playlist.sh`; optional `iconv` (UTF-8); `--by title` uses `ffprobe`/`metaflac` when present |
| playlist-normalize / playlist-dedupe | `lib/playlist.sh` only (`flock`); `--by title` / `--dedupe --by title` use tags when `ffprobe`/`metaflac` available |
| playlist-generate | `lib/playlist.sh`; `#EXTINF` from `ffprobe`/`metaflac` when present (still works without — paths only) |
| playlist-export | `lib/playlist.sh`, coreutils (`cp`) |
| album-audit | `ffprobe`; `metaflac` used for FLAC tags when present |
| path-audit | coreutils; optional `iconv` (UTF-8 name check) |
| junk-cleanup | coreutils only |
| perms-normalize | coreutils (`stat`, `chmod`) |
| dynamics-report | `ffmpeg`/`ffprobe` (`ebur128` filter), `awk` |
| spectrogram-export | `ffmpeg` (`showspectrumpic`); **sox** preferred for FLAC/WAV/AIFF |
| gapless-audit | `ffprobe`, `od`, GNU `dd`, `grep` |
| tags-lookup | **fpcalc** (chromaprint) + **curl**; optional `jq`; AcoustID client key ([enrichment.md](enrichment.md)) |
| audio-lyrics | `ffprobe`; `metaflac` for `--import` |
| audio-compare | `ffmpeg`/`ffprobe`; `--mode=streaminfo` needs `metaflac` |
| genre-canonicalize | `ffmpeg`/`ffprobe`; `metaflac` preferred for FLAC |
| library-prune | coreutils only |
| empty-dirs | coreutils (`find`, `rmdir`) |
| multi-disc-layout | `flac`, `metaflac` |
| waveform-export | `ffmpeg` (`showwavespic`) |

## Arch / CachyOS

```bash
# Core (flac→metaflac, ffmpeg→ffprobe; iconv via glibc)
sudo pacman -S flac ffmpeg shellcheck

# Optional extras used by discs / authenticity / playlists-adjacent tools:
sudo pacman -S libdvdcss cdparanoia libbluray libaacs sox mediainfo musepack-tools chromaprint dvdbackup
# libbdplus / makemkv often AUR; KEYDB.cfg is operator-supplied (see discs.md)
# rsgain often AUR/chaotic-aur (flac-replaygain)
```

Verify providers:

```bash
pacman -Qo "$(command -v iconv)"    # glibc
pacman -Qo "$(command -v ffprobe)"  # ffmpeg
pacman -Qo "$(command -v metaflac)" # flac
```

## Debian / Ubuntu

```bash
# Core (flac→metaflac, ffmpeg→ffprobe; iconv via libc-bin)
sudo apt-get install flac ffmpeg shellcheck

# Discs / optional:
sudo apt-get install libdvdcss2 cdparanoia libbluray2 libaacs0 dvdbackup
# Optional: sox mediainfo musepack-tools libchromaprint-tools
#   (dsf-to-flac DFF / flac-authenticity -p / flac-to-mpc / audio-dupes fpcalc)
# Ensure ffmpeg has lame/opus/vorbis/speex (universe builds usually do)
# flac-replaygain: apt install rsgain (Debian/Ubuntu) or loudgain
```

```bash
dpkg -S "$(command -v iconv)"     # libc-bin
dpkg -S "$(command -v ffprobe)"   # ffmpeg
dpkg -S "$(command -v metaflac)" # flac
```

## Fedora

Enable [RPM Fusion](https://rpmfusion.org/) (free + nonfree) first — stock Fedora often lacks `ffmpeg` and `libdvdcss`.

```bash
# After RPM Fusion:
sudo dnf install flac ffmpeg ShellCheck
# Discs / optional:
sudo dnf install libdvdcss cdparanoia libbluray libaacs sox mediainfo \
  musepack-tools chromaprint dvdbackup
# ReplayGain: prefer rsgain from COPR if available, else loudgain
```

```bash
rpm -qf "$(command -v iconv)"     # glibc-common
rpm -qf "$(command -v ffprobe)"   # ffmpeg
rpm -qf "$(command -v metaflac)" # flac
```

Takc is not packaged — download from the upstream TAK site and set `AUDIO_UTILS_TAKC` (see [tak.md](tak.md)).

Streaming DRM (Widevine, etc.) is **not** supported — see [streaming.md](streaming.md).

## See also

[docs index](README.md) · [playlists.md](playlists.md) · [discs.md](discs.md) · [tak.md](tak.md) · [lossy.md](lossy.md) · [dsd.md](dsd.md) · [formats.md](formats.md) · [adding-a-converter.md](adding-a-converter.md) · [adding-a-util.md](adding-a-util.md) · [root README](../README.md)
