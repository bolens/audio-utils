# Legacy capability contracts

Retrospective inventory at `17a0a2bdd5b48a7a887905875a1cd6d5ccc31ca9`, audited
2026-09-06. This extends the six shared requirements in [spec.md](spec.md) to
all 35 converters, 59 utilities, and their supporting public interfaces.

## Contract authority

The tool README and topic documents linked below are incorporated into this
specification. Their input formats, options, defaults, output names, write gates,
verification rules, and limitations are requirements, not optional examples.
The generated command-reference blocks remain single-sourced from CLI help.
Do not copy those blocks into Spec Kit or silently broaden a tool's promises
using another converter's behavior. A disagreement between code, help, and these
contracts requires investigation and a recorded correction.

The [coverage table](legacy-coverage.md) assigns every current tool to a contract
and names its implementation and acceptance fixtures. Fixture links locate checks.
They do not assert that every branch has been executed or that hardware tests ran.

## Conversion acceptance

- **LC-001, lossless hub and PCM remux:** WAV, AIFF/AIF, CAF, ALAC, WavPack,
  APE, TAK, and TTA conversions to/from FLAC, plus WAV/AIFF remuxes and
  Shorten decoding, MUST preserve the decoded PCM identity promised by
  [formats](../../docs/formats.md). New FLAC output must pass `flac -t`.
  A missing decoder, corrupt source, identity mismatch, or publication failure
  must retain the source and report failure. Existing output is accepted by the
  tool's sibling verification, not existence alone. Explicit `-d` and `-D`
  retain their different conversion and existing-output cleanup meanings.
  APE encoding uses `mac`; TAK encoding uses Takc. Their documented tag/artwork
  losses remain visible and are not covered by a PCM-equivalence claim.
- **LC-002, lossy derivatives and normalization:** MP3, Opus, AAC, Vorbis,
  WMA, Speex, and Musepack encoders MUST accept only their documented quality
  profiles and retain the defaults in [lossy](../../docs/lossy.md).
  Verification uses a successful stream probe and approximately 50 ms duration
  tolerance, not original PCM equality. Unsupported rate/channel layouts may
  be resampled/downmixed by default, while `-N` rejects that transformation.
  `lossy-to-flac` must skip ALAC-in-M4A and must not claim restored quality.
  Existing lossy siblings use the explicitly weaker probe-only skip/cleanup rule.
- **LC-003, DSD:** DSF/DFF conversion MUST produce the selected PCM derivative,
  default 88200 Hz and 24-bit, with the documented SoX DFF fallback.
  Verification compares decoded PCM, not DSD bitstream identity. See
  [DSD](../../docs/dsd.md).
- **LC-004, CUE and streams:** CUE conversion MUST use single-image `INDEX 01`
  boundaries at 75 frames/second, sanitize output titles, and retain the sheet
  and image. It rejects deletion options. CUE audit additionally supports
  multiple FILE sections, which does not imply conversion support.
  Stream extraction MUST produce one indexed FLAC per audio stream and retain
  its container if any stream fails. Container deletion with `-d` is explicit
  and discards non-audio content too. See [CUE](../../docs/cue.md),
  [streams](../../conversion/streams-to-flac/README.md), and
  [local streaming scope](../../docs/streaming.md).
- **LC-005, optical and preservation packages:** DVD conversion MUST accept
  on-disk VIDEO_TS and skip menu VOBs. CDDA MUST use its explicit device/output
  contract. Blu-ray MUST distinguish decrypted media from authored titles,
  use MakeMKV for BDMV/device title resolution, and not treat raw STREAM clips
  as titles. Checksummed staging, title selection, source-stream provenance,
  chapter reconstruction, optional original streams, signatures, PAR2, sealing,
  quick verification, full audit, and last-written completion markers follow
  [discs](../../docs/discs.md) and the Blu-ray command reference. Stale audio,
  incomplete extraction, inventory failure, or failed verification must not be
  labeled complete. No bundled keys or streaming DRM support is implied.
- **LC-006, audiobooks:** Joining tracks MUST use bytewise filename order,
  measured chapter boundaries, documented AAC/Opus/ALAC options, and the
  parent-directory M4B output. Splitting MUST require chapters, create numbered
  tracks, retain the book, and support the documented Opus fallback.
  Both reject source deletion. Chapter editing MUST require explicit embedding
  intent and a usable metadata file. Audiobook tags and audits retain their
  scope filters, role mapping, total/sequence checks, and report/apply distinction
  in [audiobooks](../../docs/audiobooks.md).

## Utility acceptance

- **LC-007, metadata and playback tags:** Each FLAC/audio artwork, tags,
  ReplayGain, tempo, key, lyrics, classical-role, and genre tool MUST follow its
  own default mutation mode. They do not all require `--apply`. Existing BPM,
  key, artwork, and gain skip/overwrite policies remain tool-specific.
  FLAC metadata editing and other-container stream-copy remuxes must not be
  described as byte-identical containers. Lyrics remain local, imports remain
  FLAC-only, and genre custom maps take precedence over built-ins. Missing
  dependencies must not be interpreted as successful analysis.
- **LC-008, integrity and analysis:** FLAC verification, library/album/CUE/rip-log
  audits, completeness checks, gapless inspection, lossy health, authenticity,
  path portability, silence/dynamics analysis, and inventories MUST report the
  precise finding defined in their tool contract. Findings normally return 1.
  Authenticity, duration outliers, peak comparison, and bitrate floors are
  heuristics/policy checks, not proof of provenance or subjective quality.
  Read-only means media is unchanged; logs, explicitly requested images,
  inventory reports, and snapshots may still be written. Failed required report
  publication must fail the run. Quick archive audit must not imply full decode,
  semantic manifest verification, or PAR2 audit.
- **LC-009, duplicates and library hygiene:** Audio and FLAC duplicate tools
  MUST retain their distinct fingerprint/decoded-MD5/STREAMINFO identities.
  Hardlink application is explicit and adopts the keeper's entire inode,
  including metadata, so audio identity does not imply identical original tags.
  Duplicate-state filenames follow FR-008; index failures must fail the scan. Library sync/prune use relative
  stem presence, not audio matching. Tree comparison is one-directional and
  size-only unless `--hash`; audio comparison has separate MD5/STREAMINFO/peak
  modes. PCM cleanup must require a valid equal-audio FLAC before deletion.
  Junk cleanup deletes only classified findings with `-d`; empty-directory
  cleanup uses `rmdir`. Permissions and multi-disc layout require `--apply`
  and retain ownership and collision limits. Hash sidecars verify file bytes,
  not decodeability, and writing/overwriting them remains explicit.
- **LC-010, FLAC transformations:** Optimize MUST preserve PCM, tags and art,
  and skip a non-smaller result unless forced. Strip and rename retain their
  documented in-place defaults and selected metadata/layout options.
  Resampling MUST be down-only unless upsampling is explicit, with rate and
  depth considered independently. Silence splitting requires at least two kept
  segments; trimming retains padding/minimum-duration and edge selection rules.
  These sample-changing operations cannot inherit the unchanged-PCM claim.
  FLAC image+CUE export requires compatible tracks and retains source tracks.
  Publication failure must fail the run, including directory collisions; the two
  output files are not an atomic transaction and a first published image can
  remain if publishing its CUE fails. Multi-disc layout validates all discovered
  album FLACs before moving any of them.
- **LC-011, playlists and visual outputs:** M3U/M3U8, PLS, and XSPF parsing,
  URI/path conversion, identity modes, ordering, first-occurrence deduplication,
  generation, filtered finalization, and export MUST follow
  [playlists](../../docs/playlists.md) and each tool README. Export copies media
  without transcoding, uses its documented same-size resume heuristic, and
  reports partial exports as findings. Visual outputs retain the complete source
  filename, validate PNGs before atomic installation, and preserve prior images
  on failed replacement. A plot is not an automated authenticity verdict.
- **LC-012, enrichment and MCP:** `tags-lookup` MUST remain report-only and
  require a supplied AcoustID key. Requests send fingerprint/duration, not audio;
  throttling is per worker. Missing/mismatched/no-match identifiers are findings,
  not automatic tag edits. See [enrichment](../../docs/enrichment.md).
  MCP MUST retain explicit input selection, destructive/network opt-ins, typed
  policy ranges, generic argument forwarding, bounded output, JSON-RPC framing,
  and stderr logging. The Node gateway retains exact Host/Origin policy,
  bounded/expired sessions, loopback defaults, and Bash-owned tool semantics in
  [MCP](../../docs/mcp.md). It does not supply authentication.

## Supporting interfaces

- **LC-013, discovery, configuration and execution:** Shared roots resolve
  explicit arguments, configured roots files, and legacy roots according to
  [requirements](../../docs/requirements.md) and [config.example](../../config.example).
  Roots files preserve spaces but are line-delimited. NUL discovery is the path
  for newline-containing directory names. Configuration accepts its documented
  key allowlist without executing shell code and preserves environment precedence.
  The driver retains exclusions, per-item failure accounting, bounded parallelism,
  safe temporary ownership, logging formats, and source-deletion guards.
  Custom optical CLIs keep their different meanings for `-d` and `-D`.
- **LC-014, maintenance interfaces:** Make aliases and discovery, scaffolds,
  generated help synchronization, documentation checks, coverage exemptions,
  fixture isolation, test selection, CI selection, codec installers, Cursor
  configuration helpers, container entry points, and cleanup tools MUST retain
  their documented contracts in the [supporting coverage](legacy-coverage.md).
  Test selection that matches no function/file returns 2. FR-007 prohibits
  swallowed assertion failures. Codec installation and updates are explicit
  network/installation operations outside the offline media-tool promise.
  Docker and delivery requirements remain in [spec 002](../002-docker-runtime/spec.md).

## Future changes

For a new public command or materially changed option, update its owning contract,
acceptance fixtures, and this coverage mapping in the same change. Keep detailed
CLI options in generated help and topic documents. Retrospective adoption is
complete only for mapped surfaces; unavailable hardware or optional dependencies
remain execution limits, not missing design work or silently passed checks.
