# m4b-to-tracks

One `.m4b` → per-chapter files in `<stem>/` beside the book
(`NN - Title.m4a`, stream-copy when possible). Opus falls back to `.opus` if
`.m4a` remux fails. Fails when the container has no chapters. Source `.m4b`
is kept (`-d`/`-D` rejected).

See [audiobooks](../../docs/audiobooks.md). Part of **[audio-utils](../../)**.

```bash
./m4b-to-tracks.sh -n DIR
make help
```
