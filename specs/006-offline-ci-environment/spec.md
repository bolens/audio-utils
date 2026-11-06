# Offline Audio CI environment

The implementation baseline is 7941996977657a8ad3eb08642aa19ca18e8d0a0f,
based on accepted canonical CI revision
2d32e153080d5551bedc228f1cd042764da9da94. The native consumer pins the
admitted public manifest and verifies its complete input key before running
current source. Image admission, public pull verification and protected source
delivery are distinct required boundaries. Cold Nix network fetches can exceed a
workflow deadline; a longer deadline alone does not provide deterministic
execution.

Prepare an immutable public toolchain bound to the complete locked environment
and reviewed dependency declarations. Execute the unchanged full development gate
against current source with OS-level networking disabled, fresh per-container
state, both forge-resolved workspace paths and explicit bounded resources. Preserve media,
source safety, six native check identities, credentials policy and publishing.

Acceptance requires real content verification and full-gate executions, including
a deliberately failing current-source test with unchanged environment key. Image
preparation, unit mocks and operator-authored metadata are not readiness evidence.
No shared writable host store, broad credential, old baked source, skipped tier or
network fallback is permitted. See the owning [runbook](../../docs/offline-ci-environment.md).

Dependency realization and metadata serialization use separate sequential guarded
RUNs. Stable public dependency input changes invalidate the first layer; late
checker/provenance changes reuse it. The second phase has OS networking disabled
and materializes only the exact revision/NAR-pinned CLI root from cached source,
then exports closed public Git tree/blob packs and serializes metadata. Only
SQLite-mapped declared tree closures may be retained, without refs, commits,
configuration, hooks, alternates or unreachable objects. Both cache formats are
strictly hydrated into fresh private runtime state and verified before tests.
Known locked NARs are verified from exact raw Git content; missing canonical NAR
pins remain explicit and are not fabricated. Pack/object bounds and exact census
hashes fail closed on missing, corrupt or additional objects. Virtual flake
metadata is not registered-source proof;
missing content must fail rather than trigger an online fallback. Both executions enforce
2 CPUs/4 GiB/no swap themselves. Failures report static phase/reason codes and safe
counts; arbitrary exception or cache values are not printed. Preparation success
still does not establish actual offline readiness.

Runtime setup uses separate empty private user/global npm configuration files in
each fresh state directory. Both are mode 0600 under a mode-0700 parent, so npm
cannot load the same config path twice or inherit operator configuration. Forced
offline npm behavior, verified content cache and the complete gate remain intact.
Partial successful gate cases do not satisfy the six-case and supplemental-fault
acceptance requirements.
