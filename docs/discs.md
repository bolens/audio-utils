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

## Blu-ray AACS / BD+ (`bluray-to-flac`) — hybrid

Two paths:

1. **Already decrypted** — BDMV `STREAM/*.m2ts` or a directory of `.m2ts` / `.mkv` that `ffprobe` can open → per-stream FLAC (same bar as `streams-to-flac`).
2. **Encrypted disc** — when system tooling is present:
   - **libbluray** + **libaacs** (optional **libbdplus** for BD+) and an operator-supplied **`KEYDB.cfg`** under `$XDG_CONFIG_HOME/aacs/` (never vendored here), and/or
   - **MakeMKV** (`makemkvcon`, or `AUDIO_UTILS_MAKEMKV=/path/to/makemkvcon`).

Device rip: `bluray-to-flac.sh -D /dev/sr0` (or `AUDIO_UTILS_BD_DEVICE`). Prefer MakeMKV for devices when available.

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

Place `KEYDB.cfg` at `${XDG_CONFIG_HOME:-$HOME/.config}/aacs/KEYDB.cfg`. This repo will not download or ship it.

BD+ titles may need **libbdplus** + operator VM/cache dumps, or MakeMKV. Fail closed with install hints when streams are unreadable.

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
| Blu-ray unreadable | KEYDB.cfg present? libaacs/libbluray? Try MakeMKV; or use decrypted M2TS/MKV |
| BD+ fail | libbdplus + dumps, or MakeMKV |

Streaming DRM (Widevine / FairPlay / …) is documented in [streaming.md](streaming.md) — forever out of scope.

## See also

[docs index](README.md) · [requirements.md](requirements.md) · [streaming.md](streaming.md) · [formats.md](formats.md) · [`util/audit/disc-inventory/`](../util/audit/disc-inventory/) · [root README](../README.md)
