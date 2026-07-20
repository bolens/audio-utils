# cdda-to-flac

Rip audio CD tracks via **cdparanoia** → verified FLAC.

```bash
./cdda-to-flac.sh                  # default /dev/sr0 → ./cdda-rip/
./cdda-to-flac.sh /dev/sr1 -o ~/Music/Album
./cdda-to-flac.sh -n               # dry-run: list tracks
```

Part of **[audio-utils](../)**.
