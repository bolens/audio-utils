# flac-to-tak

FLAC → TAK via Takc; verify by decode MD5. Default preset p2.

Limitation: `Takc` writes no tags, so Vorbis comments and artwork are not
carried into the `.tak` output. When the source has tags, the success log
notes column records `tags=dropped`. Re-tag with an APEv2 tagger if needed.

Part of **[audio-utils](../../)**.

## Presets and round-trip

Takc presets `p0` through `p5`, with supported `e`/`m` modifiers, trade encode
time for compression; `p2` is default. Set `AUDIO_UTILS_TAKC` when Takc is not
discoverable, and use Wine for its Windows executable.

```bash
./flac-to-tak.sh -n -Q p2 /path/to/album
./flac-to-tak.sh -Q p4m /path/to/album
```

The source is tested, encoded by Takc, decoded again, and compared by PCM MD5
before installation. Existing TAK siblings must decode to matching audio before
skip or cleanup. Because tags and artwork are dropped, preserve FLAC or arrange
separate APEv2 tagging before `-d`/`-D`. See [TAK setup](../../docs/tak.md).

<!-- BEGIN GENERATED COMMAND REFERENCE -->
## Command reference

This block is generated from the current `--help` output. Run
`scripts/sync-tool-readmes.sh` after changing CLI options.

```text
Convert FLAC -> TAK via Takc with MD5 verification.

Usage:
  flac-to-tak.sh DIR [DIR ...]
  find-*-dirs.sh | flac-to-tak.sh

Options:
  -f FILE  -d  -D  -L FILE  -S FILE  -n  -y  -j N  -q  -v  -h  --version
  -Q PRESET / --quality PRESET   TAK preset p0-p5[em] (default p2)
  Env: AUDIO_UTILS_TAK_PRESET, AUDIO_UTILS_TAKC

Exit codes: 0 ok, 1 failures, 2 usage/deps
Shared file tools: --exclude GLOB (repeatable, case-sensitive source basename glob)
```
<!-- END GENERATED COMMAND REFERENCE -->
