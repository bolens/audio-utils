# Discs: DVD CSS / CPPM / CDDA

Intended for archiving discs **you are allowed to copy**. This project does **not** ship CSS keys or circumvention blobs — install distro libraries yourself.

## DVD-Video CSS (`dvd-to-flac`)

- Needs **libdvdcss** on the system.
- Input: on-disk `VIDEO_TS` (ripped/copied tree). Device→backup via `dvdbackup` is available in `lib/dvd.sh` when that CLI is installed.
- Audio streams from `VTS_*.VOB` (menu `*_0.VOB` skipped) → FLAC beside the tree.

```bash
# Arch
sudo pacman -S libdvdcss
# Debian/Ubuntu
sudo apt-get install libdvdcss2
```

Env: `AUDIO_UTILS_DVD_DEVICE` (for backup helpers), paths passed as `VIDEO_TS` dirs to the tool.

## DVD-Audio CPPM

Open Linux CPPM tooling is scarce. Prefer **already-decrypted** AUDIO_TS / AOB inputs and `streams-to-flac`. Encrypted CPPM-only discs fail closed with a clear message.

## CDDA (`cdda-to-flac`)

- Requires **cdparanoia**.
- Optional: **whipper** for MusicBrainz / AccurateRip (not required).
- Device: `AUDIO_UTILS_CD_DEVICE` or `-D /dev/sr0` (default `/dev/sr0`).
- Output directory defaults under the working tree (`./cdda-rip/` unless configured).

```bash
sudo pacman -S cdparanoia   # Arch
sudo apt-get install cdparanoia
```

## Troubleshooting

| Symptom | Check |
|---------|--------|
| CSS / cannot read VOB | libdvdcss installed? readable VIDEO_TS? |
| No tracks on CD | correct `/dev/srN`? permissions in `cdrom` group? |
| CPPM fail | use decrypted dump; see requirements |

Blu-ray AACS / BD+ are **out of scope**.
