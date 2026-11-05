# Implementation plan

1. Bind the existing Nix/base/CLI/npm declarations and conservative mixed gate
   declarations; reject unresolved imports, overrides and context leakage.
2. Prepare only allowlisted public inputs in one resource-checked Docker RUN.
   Keep private builder COW state and selected public fetcher metadata.
3. Run exact pinned devenv against the current checkout with a small environment
   allowlist, fresh state, forced npm offline and actual network isolation.
4. Independently verify the resulting image/content, both workspace roots and
   full-gate baseline, then inject an unkeyed failing current-source test.
5. After proof and review, publish an immutable ci-env-KEY/digest to the existing
   public Audio package, then change both native profiles without new contexts.
   Existing credentials and publication controls remain separate.

No live build, artifact push, source commit or pipeline cutover occurs in the
initial candidate review. The owning runbook defines the later admission path.
