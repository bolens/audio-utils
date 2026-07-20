# Requirements

Core (all tools): Linux, `bash` 4+, `flac`, `ffmpeg`/`ffprobe`, `flock`, GNU `find` (`-printf`), coreutils.

| Tool / feature | Extra dependency |
|----------------|------------------|
| flac-to-mp3 | ffmpeg `libmp3lame` |
| flac-to-opus | ffmpeg `libopus` |
| flac-to-aac | `libfdk_aac` (preferred) or ffmpeg `aac` |
| flac-to-vorbis | ffmpeg `libvorbis` |
| flac-to-alac / alac-to-flac | ffmpeg `alac` |
| flac-to-wv / wv-to-flac | ffmpeg `wavpack` |
| flac-to-ape | ffmpeg **ape encoder** (often missing in distro builds) |
| ape-to-flac | ffmpeg ape **decoder** (usually present) |
| flac-to-tak | Official **Takc** (+ Wine if `.exe`); see [tak.md](tak.md) |
| tak-to-flac | ffmpeg TAK decoder and/or Takc |
| dvd-to-flac | **libdvdcss**; optional `dvdbackup` |
| cdda-to-flac | **cdparanoia**; optional `whipper` |
| cue / remux / streams | core set only |

## Arch / CachyOS

```bash
sudo pacman -S flac ffmpeg shellcheck
# optional:
sudo pacman -S libdvdcss cdparanoia
# libfdk-aac may be in AUR / extra-ffmpeg builds
```

## Debian / Ubuntu

```bash
sudo apt-get install flac ffmpeg shellcheck libdvdcss2 cdparanoia
# Ensure ffmpeg has lame/opus/vorbis (universe builds usually do)
```

Takc is not packaged — download from the upstream TAK site and set `AUDIO_UTILS_TAKC` (see [tak.md](tak.md)).
