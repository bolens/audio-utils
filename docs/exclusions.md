# Source exclusions

Shared-driver file tools accept repeatable `--exclude GLOB` or `--exclude=GLOB`:

```sh
util/flac/flac-verify/flac-verify.sh --exclude 'preview*' --exclude '*.backup.flac' ./album
```

Quote patterns so the calling shell does not expand them. Patterns use case-sensitive Bash glob matching against each source basename, including hidden names. A match to any pattern removes that source from the batch before plugin acceptance, disk checks, conversion, cleanup, or deletion. Excluded job sources remain untouched even when deletion was requested. Exclusions select job inputs, not payloads referenced by an accepted CUE, playlist, or archive marker. An all-excluded batch has the existing no-matching-files behavior and succeeds without processing files.

Audio scanning remains nonrecursive. Pass each directory as usual. This differs from the newer archiving, image, and video suites, whose exclusions match recursive paths relative to each input root. `--` ends option parsing. Missing or empty exclusion patterns return usage status 2.

Directory-level tools such as `empty-dirs` reject exclusions. Whole-album plugins also reject them: `audio-replaygain`, `flac-replaygain`, `tracks-to-m4b`, `flac-cue-export`, `playlist-generate`, `multi-disc-layout`, `album-audit`, `album-incomplete`, and `audiobook-audit`. This includes track mode in the ReplayGain tools. These tools rescan their input directory and cannot yet honor partial source selection. Custom CLIs and MCP arguments do not gain this flag. Existing verification, publication, output collision, and source-deletion rules are unchanged.
