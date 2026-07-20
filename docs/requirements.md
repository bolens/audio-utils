# Requirements

Core (all tools): Linux, `bash` 4+, `flac`, `ffmpeg`/`ffprobe`, `flock`, GNU `find` (`-printf`), coreutils.

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

## Arch / CachyOS

```bash
sudo pacman -S flac ffmpeg shellcheck
# optional:
sudo pacman -S libdvdcss cdparanoia libbluray libaacs sox mediainfo musepack-tools
# libbdplus / makemkv often AUR; KEYDB.cfg is operator-supplied (see discs.md)
# libfdk-aac may be in AUR / extra-ffmpeg builds
# rsgain often AUR/chaotic-aur (flac-replaygain)
```

## Debian / Ubuntu

```bash
sudo apt-get install flac ffmpeg shellcheck libdvdcss2 cdparanoia libbluray2 libaacs0
# Optional: sox mediainfo musepack-tools (dsf-to-flac DFF / flac-authenticity -p / flac-to-mpc)
# Ensure ffmpeg has lame/opus/vorbis/speex (universe builds usually do)
# flac-replaygain: apt install rsgain (Debian/Ubuntu) or loudgain
```

Takc is not packaged — download from the upstream TAK site and set `AUDIO_UTILS_TAKC` (see [tak.md](tak.md)).

Streaming DRM (Widevine, etc.) is **not** supported — see [streaming.md](streaming.md).
