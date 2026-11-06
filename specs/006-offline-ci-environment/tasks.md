# Tasks

- [x] Add input identity, clean public context and strict runtime checker candidate.
- [x] Remove inherited test selectors/dry-run settings through an environment allowlist.
- [x] Add focused regression fixtures and existing development-gate coverage.
- [x] Split stable dependency realization from late offline source/metadata preparation; guard both RUNs.
- [x] Add static late-refusal diagnostics with unknown-value redaction.
- [x] Pin the CLI-source NAR and require cache-only root materialization in network-none phase two.
- [x] Add bounded declared tree/blob pack export and fresh v3/v4 runtime hydration with exact census/NAR guards.
- [x] Add real Git fixtures for missing trees, gitlinks, corrupt/extra objects, replacement refs and raw-attribute-independent content.
- [x] Isolate npm user/global configuration in distinct private empty files and verify them while the gate executes.
- [x] Complete independent implementation source review and focused lint/unit/installed pre-commit checks.
- [ ] Complete normal full pre-push checks and protected source delivery for the final consumer.
- [x] Complete new-image content and runtime admission with all six actual gate cases and terminal lifecycles. [A1, A2]
- [x] Verify guarded realization history, the new constrained late phase and safe layer reuse without host store/auth/cache mounts. [A0]
- [x] Verify image filesystem, dependency content and no old application source. [A1]
- [x] Pass full network-none gate at both forge-resolved workspace paths with fresh random state. [A2]
- [x] Prove current-source negative test fails with unchanged environment key. [A2]
- [x] Prove both missing-CLI and corrupt-npm faults fail for their exact required reasons. [A3]
- [x] Publish only the admitted `ci-env-KEY` tag, then verify the immutable public manifest digest and anonymous pull. [A4]
- [ ] Complete protected review of both digest-pinned consumer profiles and owning docs.
- [ ] Verify anonymous exact-digest pull on the second runner before protected main merge.
- [ ] Prove genuine native PR/main execution and Gitea source/profile parity.

## Completed image admission and publication — consumer delivery pending

Implementation baseline: `7941996977657a8ad3eb08642aa19ca18e8d0a0f`.
Environment key:
`bfecb313be6057da1724ad616b186d3e70345109e4a8627e0e7d8b9ec5203d64`.
The 28 focused tests passed; directly captured raw output SHA-256:
`a5886c89b2a96f05bd4328c4f13ee3ff8ee2a1bc7f7b7b0e8e1b0fbb58f37456`.

- **A0 — preparation and reuse:** the immutable successful-build record is
  `98aa3955d32981f8217bf03a8638a80b23f2cf4d8746e66da947a0dccde65b6c`.
  The reused realization layer is bound to the earlier actual resource/source
  proof `1211819394ec4212bd3d7eb49a5c6782cf277dd533b996b330118721d37f30fb`,
  the identical 874-byte first-stage prefix and all eight input bytes/modes.
  This is verified cache reuse, not a claim that the first phase ran afresh.
- **A1 — independent content admission:** audit receipt
  `ff4f7485f42b7eb790dc5bc1366269400d68d37974c864d0471b341c27cb7507`;
  audit lifecycle
  `3375acb1ea76e4b867fbb9a53e84c34a34f1fe107ca52cfacd6cd91a7a5a3bde`.
  Content/NAR/public-source/privacy checks passed, with both owned containers
  stopped and no lifecycle failures.
- **A2 — six real gate cases:** acceptance receipt
  `e81422a5f4455833f75305916842de4d871149a011a81fb0cbdd1df1ff03cc81`;
  lifecycle
  `4db1cb6e84727609b31a2124673c14028a7d1c4adda8f41c2c0352583c97d9c1`.
  The canonical fresh run and four fresh current-source runs passed: two at each
  forge-resolved path. Canonical Python families were `[15, 12, 8, 8, 6]`;
  current source added its independently bound 28-test checker family. All
  positives matched Node SPEC 8 pass/0 skipped and Bash 63 files, 512 pass,
  0 fail, 13 skips. No additional skips were accepted. The unchanged-key
  source-negative case actually executed the harness failure: Bash 64 files,
  512 pass, 1 fail, 13 skips, exit 1. All six owned containers stopped with
  finished lifecycle and no failures.
- **A3 — supplemental faults:** acceptance receipt
  `2215d474b4e09393cff66e3ba765f4f783e9cc3ad0143e9308d6ad5eb7f530a1`;
  lifecycle
  `0f9b9ee035403361cf48c6f5990b07f648369b1441e68357099a52eb8104ee34`.
  Missing CLI was refused before gate/harness execution. Corrupt npm content
  produced exit 1 for the required offline/integrity reason. Both owned
  containers stopped with finished lifecycle and no failures.

All admission identities are bound by those receipts to the same source, key,
image and operation. Publication control was frozen before guarded scheduling
release, control SHA-256
`ec3fe532d27ff4e40dd535f4e3520709e4a41ae9648efeca9b9b3316746707ec`.
- **A4 — exact public artifact:** the single
  `ghcr.io/bolens/audio-utils:ci-env-bfecb313be6057da1724ad616b186d3e70345109e4a8627e0e7d8b9ec5203d64`
  tag was published for that admitted source/key/image/operation. Public manifest:
  `sha256:536ba4b1712a66adbaca85ac889e6d8fd7e72deb125449434d357e5dbdbbe532`;
  config:
  `sha256:b7bb899e49bd808b0461c08a50d9b2542d4128fc57de894be546da09b49d9dee`.
  Publication receipt
  `3557f027f62ded50e17619f7e763359adbdabd8541125927675f5867c0829c1f`
  verifies the public digest and actual anonymous Docker pull on the build host.
  Runtime aliases were not written. Auth cleanup receipt
  `fef43851a8020c68302302a815781eced8e0c57821c48558459789e8f26e862e`
  records removal of the temporary private auth and preservation of the existing
  permanent credential.

Protected consumer delivery and second-runner operational verification remain
pending; publication is not a claim that those checks ran. Keep their tasks open
until their actual receipts exist. Private full logs and credential material
stay outside source.

## Post-merge evidence ownership

Before merge, this tracked checklist can record only already observed checks.
The owning protected PR's immutable checks and the coordinator's final receipt
record the actual merged SHA/tree, genuine GitHub main pipeline and Gitea
PR/main parity afterward. They own that post-merge completion; a follow-up source
commit solely to pre-claim or tick its own future main check is unnecessary.
Record the public manifest and delivery links in the final receipt/PR handoff,
without marking an unperformed stage complete in this source snapshot.
