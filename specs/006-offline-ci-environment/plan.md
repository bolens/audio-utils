# Implementation plan

1. Bind the existing Nix/base/CLI/npm declarations and conservative mixed gate
   declarations; reject unresolved imports, overrides and context leakage.
2. Prepare only stable allowlisted public dependency inputs in the first
   resource-checked Docker RUN. Serialize checker/provenance metadata in a second
   guarded network-none RUN. Materialize only the revision/NAR-pinned CLI root
   from its cached source, without running `nix flake archive`, evaluating dependency
   outputs, or realizing missing dependencies. Keep private
   builder COW state and selected public fetcher metadata; never use host caches.
   Export only mapped tree/blob closures as bounded, self-contained packs for
   v3/v4 cache formats. Reimport into fresh bare repositories and verify exact
   reachability, census and known source NARs, then repeat hydration before tests.
   Preserve absent canonical NAR pins without lock mutation or invented values.
   Report only static late-refusal phases/reasons and safe counts.
3. Run exact pinned devenv against the current checkout with a small environment
   allowlist, fresh state, distinct empty private user/global npm configuration
   files, forced npm offline and actual network isolation. Require complete
   current-namespace topology/capability admission, not an interface-name-only
   rule, while preserving independent Docker network-none and no-shared-Nix bounds.
4. Independently verify image/content and both workspace roots. Observe an actual
   canonical-source full-gate baseline with five environment files byte-identical
   to the candidate, then compare current-source counts plus its separately
   observed helper-test family. Inject an unkeyed failing current-source test.
5. After proof and review, publish an immutable ci-env-KEY/digest to the existing
   public Audio package, then change both native profiles without new contexts.
   Existing credentials and publication controls remain separate.

For each generation, retain actual case and lifecycle receipts; a successful
subset does not establish admission. After all six gate cases and both faults
pass, publish the single CI-environment tag and verify its public manifest and
anonymous pull. Select that digest through the protected consumer change and
verify genuine GitHub and Gitea main delivery. Keep private evidence outside the
public source tree; owning tasks record the accepted source/tree and receipt
identities.

The 213c portable namespace-policy successor requires new image admission, all six actual
gate cases, both faults and publication before selecting its digest. Historical
794 standalone receipts remain scoped to that generation. First target the
corrected native core at Grove, bind its successful full gate and compiled empty
authentication separately from Bamboo's anonymous public pull, then remove the
temporary runner target. Owning tasks retain pending evidence fields until the
actual observations exist.
