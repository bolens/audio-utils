# flac-to-speex

FLAC → Speex (`.spx`, libspeex) with duration check. Default quality: **q6**.

Speech-oriented; for music prefer Opus/MP3. `-N` refuses rate/channel fixups.

Part of **[audio-utils](../../)**.

## Intended material

Speex is a legacy speech codec. Profiles `q4` through `q8` trade size for
speech quality, with `q6` as default. Prefer Opus for new speech collections
and Opus, MP3, AAC, or Vorbis for music.

```bash
./flac-to-speex.sh -n -Q q6 /path/to/speech
./flac-to-speex.sh -Q q8 /path/to/speech
```

The encoder may resample or downmix input to a supported Speex layout. These
changes are logged; `-N` rejects the file instead. Metadata support in `.spx`
is narrower than FLAC, so inspect important custom tags.

Verification checks that the result probes and stays within about 50 ms of the
prepared input duration. It cannot establish PCM identity after lossy encoding,
and existing siblings are only probe-checked. Keep archival FLACs unless the
deletion tradeoff is intentional; always preview `-d`/`-D`. Requires FFmpeg
with `libspeex`; see [lossy behavior](../../docs/lossy.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> Speex (.spx) with verification.

Usage:
  flac-to-speex.sh DIR [DIR ...]
  find-flac-dirs.sh | flac-to-speex.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
  -Q PROFILE / --quality PROFILE
  -N / --no-resample   Fail instead of resampling/downmixing

Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
