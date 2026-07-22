# Audiobooks

Multi-file chapter libraries and single-file `.m4b` books. Shared chapter I/O
lives in [`lib/media/chapters.sh`](../lib/media/chapters.sh) (ffprobe list +
ffmetadata extract/embed).

## Tools

| Tool | Role |
|------|------|
| [`util/audiobook/chapters/`](../util/audiobook/chapters/) | List / extract / embed chapter markers |
| [`util/audiobook/audiobook-tags/`](../util/audiobook/audiobook-tags/) | Author / narrator / series normalize |
| [`conversion/tracks-to-m4b/`](../conversion/tracks-to-m4b/) | Chapter files → one `.m4b` |
| [`conversion/m4b-to-tracks/`](../conversion/m4b-to-tracks/) | `.m4b` → per-chapter files |
| [`util/audiobook/audiobook-audit/`](../util/audiobook/audiobook-audit/) | Cover / tags / chapters / series QC |

Related (not audiobook-specific): [`silence-split`](../util/flac/silence-split/)
for long-file → numbered tracks; [`cue-to-flac`](../conversion/cue-to-flac/) /
[`flac-cue-export`](../util/flac/flac-cue-export/) for CUE workflows;
[`flac-to-aac`](../conversion/flac-to-aac/) for per-file AAC (default **96**,
same speech-oriented bitrate as M4B AAC).

## Workflows

**Multi-file → M4B:**

```bash
# optional: normalize tags first
make -C util/audiobook/audiobook-tags convert-quiet -- --apply BOOKDIR
make -C conversion/tracks-to-m4b convert-quiet -- BOOKDIR
# -> parent/BOOKDIR.m4b
```

**M4B → multi-file:**

```bash
make -C conversion/m4b-to-tracks convert-quiet -- BOOKROOT
# -> BOOKROOT/<stem>/NN - Title.m4a
```

**Chapter edit:**

```bash
./util/audiobook/chapters/chapters.sh --extract=chapters.txt BOOKROOT
# edit chapters.txt (ffmetadata)
./util/audiobook/chapters/chapters.sh --embed=chapters.txt --apply BOOKROOT
```

## Codecs (`tracks-to-m4b`)

| `--codec` / `AUDIO_UTILS_M4B_CODEC` | Notes |
|-------------------------------------|--------|
| `aac` (default) | Widest player support; `-Q` / `AUDIO_UTILS_M4B_QUALITY` default **96** |
| `opus` | `libopus` in MP4/M4B; good speech efficiency; not universal |
| `alac` | Lossless chaptered books; quality ignored |

## Tag model (`audiobook-tags`)

| Role | Tags |
|------|------|
| Title | `TITLE`; single-file also `ALBUM` = book title |
| Author | `ALBUMARTIST` (fills `ARTIST` if empty) |
| Narrator | `NARRATOR` |
| Series | `SERIES`, `SERIES-PART` |
| Ids | `ASIN`, `ISBN` (preserved when present) |
| Genre | prefer `Audiobook` when empty / spoken-word junk |

## Extension preset

`find-audio-dirs.sh --preset audiobook` → `m4b m4a mp3 flac`
([`lib/media/audio_exts.sh`](../lib/media/audio_exts.sh)).

## Non-goals (v1)

- Auto chapter detection from silence (use `silence-split` first)
- DRM retail formats (Audible / Overdrive)
- Player bookmark / progress sidecars

## See also

[formats.md](formats.md) · [lossy.md](lossy.md) · [cue.md](cue.md) · [requirements.md](requirements.md)
