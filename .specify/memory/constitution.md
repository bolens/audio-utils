# audio-utils Constitution

[Documentation](../../docs/README.md)

## Core Principles

### I. Verified Audio Preservation

FLAC is the archive hub. Conversions MUST verify observable output and preserve source material unless deletion was explicitly requested and all safety checks passed. Lossy normalization MUST never be described as restoring quality.

### II. Filename and Library Safety

Paths are hostile data and may contain any valid filename characters. Tools MUST preserve names, use safe traversal/argument handling, and MUST NOT test destructive behavior against real libraries.

### III. Shared Pipeline Architecture

Tool directories remain thin and shared behavior belongs in the established core, CLI, media, and pipeline modules loaded through the canonical bootstrap. Shared modules perform no work when sourced.

### IV. Deterministic GNU/Linux Behavior

The target is GNU/Linux with Bash 4.3+. Exit codes, stdout/stderr roles, atomic output, offline defaults, and CLI contracts MUST remain consistent across tools.

### V. Layered Verification

Changes MUST add behavioral coverage at the appropriate tier and run the narrowest relevant checks before broader gates. Skipped dependency-based tiers MUST be reported, not counted as passes.

## Governance

Detailed contracts in `docs/` and `lib/README.md` are authoritative. Safety reductions require explicit approval and new regression coverage. Amendments use semantic versioning.

**Version**: 1.0.0 | **Ratified**: 2026-08-15 | **Last Amended**: 2026-08-15
