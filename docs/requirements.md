# Requirements

Core (all tools): Linux, `bash` 4+, `flac`, `ffmpeg`/`ffprobe`, `flock`, GNU `find` (`-printf`), coreutils.

## Core binaries → packages

| Binary / need | Arch / CachyOS | Debian / Ubuntu | Fedora |
|---------------|----------------|-----------------|--------|
| `bash` | `bash` | `bash` | `bash` |
| `flac` / `metaflac` | `flac` | `flac` | `flac` |
| `ffmpeg` / `ffprobe` | `ffmpeg` | `ffmpeg` | `ffmpeg` |
| `flock` | `util-linux` | `util-linux` | `util-linux` |
| GNU `find` (`-printf`) | `findutils` | `findutils` | `findutils` |
| `iconv` | **`glibc`** (base; not a separate package) | **`libc-bin`** | **`glibc-common`** |
| `sha256sum` / `md5sum` | `coreutils` | `coreutils` | `coreutils` |
| `shellcheck` (dev / `make check`) | `shellcheck` | `shellcheck` | `ShellCheck` |

`metaflac` ships in the same package as `flac`. `ffprobe` ships with `ffmpeg`. `iconv` is part of the C library package on glibc systems — do **not** install `libiconv` on Arch unless you know you need it.

## Tool extras

| Tool / feature | Extra dependency |
|----------------|------------------|
| flac-to-mp3 | ffmpeg `libmp3lame` |
| flac-to-opus | ffmpeg `libopus` |
| flac-to-aac | `libfdk_aac` (preferred) or ffmpeg `aac` |
| flac-to-vorbis | ffmpeg `libvorbis` |
| flac-to-wma | ffmpeg `wmav2` |
| flac-to-speex | ffmpeg `libspeex` |
| flac-to-mpc | **mpcenc** (`musepack-tools`) |
| flac-to-alac / alac-to-flac | ffmpeg `alac` |
| flac-to-wv / wv-to-flac | ffmpeg `wavpack` |
| flac-to-ape | ffmpeg **ape encoder** (often missing in distro builds) |
| ape-to-flac | ffmpeg ape **decoder** (usually present) |
| flac-to-tta / tta-to-flac | ffmpeg `tta` |
| shn-to-flac | ffmpeg Shorten **decoder** (no encoder) |
| lossy-to-flac | core set (decodes mp3/aac/opus/vorbis/wma/mpc; skips ALAC) |
| caf-to-flac / flac-to-caf | core set (CAF mux/demux) |
| dsf-to-flac | ffmpeg DSF demuxer; optional **sox** for DFF |
| flac-to-tak | Official **Takc** (+ Wine if `.exe`); see [tak.md](tak.md) |
| tak-to-flac | ffmpeg TAK decoder and/or Takc |
| dvd-to-flac | **libdvdcss**; optional `dvdbackup` |
| bluray-to-flac | **libbluray** + **libaacs** (+ operator `KEYDB.cfg`); optional **libbdplus**, **MakeMKV** (`AUDIO_UTILS_MAKEMKV`); or already-decrypted M2TS/MKV |
| cdda-to-flac | **cdparanoia**; optional `whipper` |
| cue / remux / streams | core set only |
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
| audio-replaygain | **rsgain** or **loudgain**, `ffmpeg`/`ffprobe` |
| audio-tags | `ffmpeg`/`ffprobe`; `metaflac` for FLAC |
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

## Arch / CachyOS

```bash
# Core (flac→metaflac, ffmpeg→ffprobe; iconv via glibc)
sudo pacman -S flac ffmpeg shellcheck

# Optional extras used by discs / authenticity / portable / playlists-adjacent tools:
sudo pacman -S libdvdcss cdparanoia libbluray libaacs sox mediainfo musepack-tools chromaprint
# libbdplus / makemkv often AUR; KEYDB.cfg is operator-supplied (see discs.md)
# libfdk-aac may be in AUR / extra-ffmpeg builds
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
sudo apt-get install libdvdcss2 cdparanoia libbluray2 libaacs0
# Optional: sox mediainfo musepack-tools libchromaprint-tools
#   (dsf-to-flac DFF / flac-authenticity -p / flac-to-mpc / audio-dupes fpcalc)
# Ensure ffmpeg has lame/opus/vorbis/speex (universe builds usually do)
# flac-replaygain: apt install rsgain (Debian/Ubuntu) or loudgain
```

```bash
dpkg -S "$(command -v iconv)"     # libc-bin
dpkg -S "$(command -v ffprobe)"   # ffmpeg
dpkg -S "$(command -v metaflac)"  # flac
```

## Fedora

```bash
sudo dnf install flac ffmpeg ShellCheck
# Optional: libdvdcss cdparanoia libbluray libaacs sox mediainfo musepack-tools chromaprint
```

```bash
rpm -qf "$(command -v iconv)"     # glibc-common
rpm -qf "$(command -v ffprobe)"   # ffmpeg
rpm -qf "$(command -v metaflac)"  # flac
```

Takc is not packaged — download from the upstream TAK site and set `AUDIO_UTILS_TAKC` (see [tak.md](tak.md)).

Streaming DRM (Widevine, etc.) is **not** supported — see [streaming.md](streaming.md).

Playlist formats and tools: [playlists.md](playlists.md).
