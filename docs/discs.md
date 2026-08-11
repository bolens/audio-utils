# Discs: DVD / Blu-ray / CDDA

Intended for archiving discs **you are allowed to copy**. This project does **not** ship CSS/AACS keys, BD+ dumps, or circumvention blobs — install distro libraries and operator key material yourself.

## DVD-Video CSS (`dvd-to-flac`)

- Needs **libdvdcss** on the system.
- Input: on-disk `VIDEO_TS` (ripped/copied tree). **`dvd-to-flac` does not call `dvdbackup`** — rip/copy the disc first, then pass the `VIDEO_TS` path.
- Optional library helper: `dvd_backup_title` in [`lib/pipeline/dvd.sh`](../lib/pipeline/dvd.sh) (needs `dvdbackup` + `AUDIO_UTILS_DVD_DEVICE`) for operators who want a separate device→folder step.
- Audio streams from `VTS_*.VOB` (menu `*_0.VOB` skipped) → FLAC beside the tree.

```bash
# Arch
sudo pacman -S libdvdcss
# Debian/Ubuntu
sudo apt-get install libdvdcss2
# Fedora (RPM Fusion)
sudo dnf install libdvdcss
```

Env: paths passed as `VIDEO_TS` dirs to the tool. `AUDIO_UTILS_DVD_DEVICE` is only for the optional `dvd_backup_title` helper, not the converter CLI.

## DVD-Audio CPPM

Open Linux CPPM tooling is scarce. Prefer **already-decrypted** AUDIO_TS / AOB inputs and `streams-to-flac`. Encrypted CPPM-only discs fail closed with a clear message.

## Blu-ray AACS / BD+ (`bluray-to-flac`)

Two paths:

1. **Standalone decrypted media** — `.m2ts`, `.mkv`, `.mka`, `.mp4`, or `.ts`
   files that `ffprobe` can open → one FLAC per audio stream.
2. **BDMV tree or device** — **MakeMKV** (`makemkvcon`, or
   `AUDIO_UTILS_MAKEMKV=/path/to/makemkvcon`) resolves authored playlists and
   performs any supported decryption before conversion.

Raw `BDMV/STREAM` clips are deliberately not extracted as titles. MPLS
playlists may join, trim, reuse, or branch clips, so clip-by-clip extraction can
duplicate or incorrectly segment a program.

Device rip: `bluray-to-flac.sh -D /dev/sr0` (or `AUDIO_UTILS_BD_DEVICE`).

```bash
# Arch (packages; KEYDB is still operator-supplied)
sudo pacman -S libbluray libaacs
# libbdplus often AUR; MakeMKV often AUR (makemkv)

# Debian/Ubuntu
sudo apt-get install libbluray2 libaacs0
# libbdplus0 / MakeMKV from your preferred source

# Fedora (RPM Fusion for some extras)
sudo dnf install libbluray libaacs
# libbdplus / MakeMKV from COPR or vendor packages
```

MakeMKV manages its own supported decryption configuration. This repo does not
download or ship keys, dumps, or MakeMKV components.

Outputs retain the container extension, such as `title.mkv.a0.flac`. Directory
inputs mirror their relative subdirectories below `flac/`. Source codec,
profile, language, stream title, and channel layout are retained as FLAC tags
when available. Lossy sources are marked `LOSSY_SOURCE=1`; Dolby Atmos and
DTS:X object data cannot be represented by FLAC.

## CDDA (`cdda-to-flac`)

- Requires **cdparanoia**.
- MusicBrainz / AccurateRip workflows (e.g. whipper) are **external** — not wired into this tool.
- Device: `AUDIO_UTILS_CD_DEVICE` or `-d /dev/sr0` (default `/dev/sr0`).
- Output directory defaults under the working tree (`./cdda-rip/` unless configured).

```bash
sudo pacman -S cdparanoia   # Arch
sudo apt-get install cdparanoia
sudo dnf install cdparanoia # Fedora
```

## Troubleshooting

| Symptom | Check |
|---------|--------|
| CSS / cannot read VOB | libdvdcss installed? readable VIDEO_TS? |
| No tracks on CD | correct `/dev/srN`? permissions in `cdrom` / optical group? |
| CPPM fail | use decrypted dump; see requirements |
| Blu-ray unreadable | Check MakeMKV support/logs; or use standalone decrypted media |
| BD+ fail | Check whether the installed MakeMKV version supports the disc |

Streaming DRM (Widevine / FairPlay / …) is documented in [streaming.md](streaming.md) — forever out of scope.

## See also

[docs index](README.md) · [requirements.md](requirements.md) · [streaming.md](streaming.md) · [formats.md](formats.md) · [`util/audit/disc-inventory/`](../util/audit/disc-inventory/) · [root README](../README.md)
