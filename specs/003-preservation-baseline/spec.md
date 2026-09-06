# Feature specification: Verified audio workflows and shared utility engine

**Created**: 2026-09-05
**Status**: Retrospective baseline
**Inspected revision**: `32517f4931d2d7f087a5bc0924e642882f075ee5`
**Input**: The owner requested a fleet-wide Spec Kit retrofit and implementation audit.

Bash audio tools use a shared plugin/CLI engine for verified conversions, metadata work, library inspection, and optional MCP access.

This specification records existing contracts after implementation. It does not
claim that the original work followed Spec Kit. New behavior requires a separate
change contract. Existing feature specifications remain authoritative within their
own scope.

## User scenarios and testing

### User story 1: Use the documented entry points (P1)

An operator selects a supported command or source workflow.

**Acceptance**: Inputs, output/status, and ownership remain consistent with the source contracts below.

### User story 2: Handle invalid input and partial failure (P2)

A configuration, dependency, subprocess, or persistence operation fails.

**Acceptance**: The named regression fixtures preserve failure reporting and recovery without claiming an unverified successful operation.

### User story 3: Maintain the contract (P3)

A maintainer changes the implementation or adds a supported capability.

**Acceptance**: The source registry, public documentation, tests, and delivery checks change together; operational actions remain separately scoped.

## Requirements

- **FR-001**: Thin tool entry points MUST load validated plugin contracts through the canonical shared module order.
- **FR-002**: Conversion pipelines MUST verify their documented audio equivalence or output integrity before publication and report publication failure as failure.
- **FR-003**: Sources MUST be retained unless an explicit deletion/cleanup mode is selected and its required verification succeeds.
- **FR-004**: Dry-run MUST avoid media/tag/deletion writes, and exclusions MUST apply before file processing or fail for tools that cannot honor them.
- **FR-005**: Parallel execution and finalizers MUST preserve successful results, report partial failure, and fail when requested reports cannot be published.
- **FR-006**: MCP entry points MUST retain declared tool schemas and explicit write policy, with optional HTTP transport security tested separately.

## Success criteria

- **SC-001**: Every requirement has a named source owner and acceptance check in `coverage.md`.
- **SC-002**: The listed native checks pass for the reviewed candidate, with unavailable environments and operational checks recorded separately.
- **SC-003**: Retrofitting preserves existing interfaces and completed specifications. Any confirmed implementation gap is corrected under an explicit requirement before it is marked complete.

## Edge cases and operational limits

Audio tools have explicit overwrite/reconversion and source-cleanup modes; they do not inherit the image/video/archive suites' unconditional no-clobber contract. No personal media library is used. Optional rsgain/loudgain, keyfinder, and Node gateway dependencies have separate evidence. Docker or live library operations remain separate from source delivery.
