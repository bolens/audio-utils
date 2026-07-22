# genre-canonicalize

Map freeform `GENRE` tags onto a small controlled vocabulary (Rock, Metal,
Electronic, …). Report-only by default; `--apply` rewrites the tag.

Optional `--map-file` with `alias<TAB>Canonical` (or `alias=Canonical`) lines —
map-file hits win over the built-in table. Unmapped genres fail; missing GENRE
is skipped.

Companion to [`util/audio/audio-tags`](../audio-tags/).

Part of **[audio-utils](../../../)**.
