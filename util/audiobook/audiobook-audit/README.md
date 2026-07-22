# audiobook-audit

Read-only QC for single-file `.m4b` books and multi-file chapter directories:
missing cover / author / narrator / title, chapterless `.m4b`, unexpected
codecs (AAC/Opus/ALAC OK), series consistency, track gaps / mixed rates.

See [audiobooks](../../../docs/audiobooks.md). Part of **[audio-utils](../../../)**.

```bash
./audiobook-audit.sh -n DIR
make help
```
