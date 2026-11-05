# Offline Audio CI environment

Prospective implementation specification. Existing CI source is based on accepted
canonical revision 2d32e153080d5551bedc228f1cd042764da9da94. The current cold Nix
network fetch can exceed a workflow deadline; a longer deadline alone does not
provide deterministic execution.

Prepare an immutable public toolchain bound to the complete locked environment
and reviewed dependency declarations. Execute the unchanged full development gate
against current source with OS-level networking disabled, fresh per-container
state, both forge workspace paths and explicit bounded resources. Preserve media,
source safety, six native check identities, credentials policy and publishing.

Acceptance requires real content verification and full-gate executions, including
a deliberately failing current-source test with unchanged environment key. Image
preparation, unit mocks and operator-authored metadata are not readiness evidence.
No shared writable host store, broad credential, old baked source, skipped tier or
network fallback is permitted. See the owning [runbook](../../docs/offline-ci-environment.md).
