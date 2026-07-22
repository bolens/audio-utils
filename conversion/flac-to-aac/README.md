# flac-to-aac

FLAC → M4A (aac) with duration check. Default quality: **96** (speech/portable).
Music libraries: `-Q 192` or `AUDIO_UTILS_AAC_QUALITY=192`.

`-N` / `--no-resample` refuses rate/channel fixups.

Part of **[audio-utils](../../)**.

```bash
./flac-to-aac.sh -n DIR
./flac-to-aac.sh -Q 192 DIR
make help
```
