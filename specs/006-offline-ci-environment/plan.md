# Implementation plan

1. Bind the existing Nix/base/CLI/npm declarations and conservative mixed gate
   declarations; reject unresolved imports, overrides and context leakage.
2. Prepare only stable allowlisted public dependency inputs in the first
   resource-checked Docker RUN. Serialize checker/provenance metadata in a second
   guarded RUN without fetching, evaluating or building dependencies. Keep private
   builder COW state and selected public fetcher metadata; never use host caches.
   Report only static late-refusal phases/reasons and safe counts.
3. Run exact pinned devenv against the current checkout with a small environment
   allowlist, fresh state, forced npm offline and actual network isolation.
4. Independently verify image/content and both workspace roots. Observe an actual
   canonical-source full-gate baseline with five environment files byte-identical
   to the candidate, then compare current-source counts plus its separately
   observed helper-test family. Inject an unkeyed failing current-source test.
5. After proof and review, publish an immutable ci-env-KEY/digest to the existing
   public Audio package, then change both native profiles without new contexts.
   Existing credentials and publication controls remain separate.

No live build, artifact push, source commit or pipeline cutover occurs in the
initial candidate review. The owning runbook defines the later admission path.
