# Documentation

Audio conversion, library maintenance, and preservation contracts.

## Start here

| Need | Owning document |
| --- | --- |
| Use the project | [README.md](../README.md) |
| Change the repository | [AGENTS.md](../AGENTS.md) |
| Deliver or recover | [RELEASING.md](../RELEASING.md) |
| Plan substantial changes | [.specify/memory/project-guide.md](../.specify/memory/project-guide.md) |
| Non-negotiable constraints | [.specify/memory/constitution.md](../.specify/memory/constitution.md) |

## Architecture

Thin tool directories load shared modules through [plugin initialization](../lib/plugin_init.sh) and
[the loader](../lib/load.sh). The [library contract](../lib/README.md) owns shared behavior.
Verification depends on the operation: lossless conversion, lossy encoding, metadata updates, and
library cleanup have different evidence and source-deletion rules. Use the relevant format or
workflow guide below.

## Deployment and recovery

[Requirements](requirements.md) owns runtime and codec support. [Container usage](docker.md) owns
mounts and execution. [RELEASING.md](../RELEASING.md) owns source and artifact delivery. New tools
follow the [converter](adding-a-converter.md) or [utility](adding-a-util.md) authoring contract,
including documentation discovery.

## Database and state

Audio files, sidecars, reports, and local caches belong to the selected workflow, not a central
database. [Formats](formats.md) owns verification and source deletion. [Enrichment](enrichment.md)
owns opt-in network behavior. Test writes, renames, and cleanup only against disposable media.

## Documentation maintenance

Keep decisions, invariants, failure modes, and recovery requirements in the owning document. Link to
commands, defaults, schemas, and generated catalogs instead of copying them. Change the owner and
affected references together. Update this index when adding or moving a guide, and verify relative
links and heading anchors. Historical specs and audits describe their recorded revision, not current
runtime proof. A topic without an implementation stays explicitly unimplemented.

## Topic guides

Index of topic docs. **Tool lists** (every converter/util path) live only in the root
[README](../README.md) — keep that table current when adding tools; link here for depth.

| Doc | Contents |
|-----|----------|
| [requirements.md](requirements.md) | Dependencies and distro install hints |
| [formats.md](formats.md) | Format hub, verification, skip/`-D` |
| [cue.md](cue.md) | CUE + image → tracks |
| [discs.md](discs.md) | DVD CSS / Blu-ray hybrid / CDDA |
| [streaming.md](streaming.md) | DRM-free local files; Widevine forever OOS |
| [tak.md](tak.md) | Takc / Wine setup |
| [dsd.md](dsd.md) | DSF/DFF → FLAC rates and sox fallback |
| [lossy.md](lossy.md) | MP3 / Opus / AAC / Vorbis / WMA / Speex / MPC + resample |
| [audiobooks.md](audiobooks.md) | M4B ↔ chapter files, tags, chapters, audit |
| [playlists.md](playlists.md) | M3U / PLS / XSPF audit, normalize, generate, smart, dedupe |
| [enrichment.md](enrichment.md) | Online metadata lookups (AcoustID / MusicBrainz) — opt-in network boundary |
| [accessibility.md](accessibility.md) | Plain-text CLI posture (screen readers, no ANSI, logs) |
| [mcp.md](mcp.md) | MCP stdio server, Cursor install, optional HTTP/SSE npm gateway |
| [third-party.md](third-party.md) | Third-party software notices and licenses (APE SDK, Shorten, Takc) |
| [releasing.md](releasing.md) | Maintainer release playbook |
| [adding-a-converter.md](adding-a-converter.md) | Converter plugin contract |
| [adding-a-util.md](adding-a-util.md) | Non-conversion util contract |

## See also

[Root README](../README.md) (tool tables) · [requirements.md](requirements.md) ·
[adding-a-converter.md](adding-a-converter.md) · [adding-a-util.md](adding-a-util.md)

- [Docker runtime](docker.md): build, mount media, and run tools.
