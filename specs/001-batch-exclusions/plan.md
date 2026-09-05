# Implementation plan

Own parsing, help, and source selection in `lib/cli/driver.sh`. Retain thin wrappers and existing plugin hooks. Filter NUL-delimited discovered source arrays before any worker or disk check. Reject `AU_QUEUE_EMPTY_DIRS` tools when exclusions are present.

Constitution checks: Bash 4.3+, no evaluation of path data, no import-time processing, no change to verification or source-deletion gates, fixtures only. Document shared-driver scope in the indexed CLI guide and add real fixture tests to `tests/functional/driver-contract.test.sh`.

Validate focused driver tests, shared library/tests checks, full native pre-push checks, and GitHub CI. Audit the final diff separately and follow the protected-main PR/squash workflow without a release tag.
