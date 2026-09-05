# Batch source exclusions

Add repeatable `--exclude GLOB` and `--exclude=GLOB` to shared-driver file tools. Match case-sensitive Bash glob patterns against each source basename before plugin acceptance, disk checks, conversion, cleanup, or deletion. Directory scanning remains nonrecursive. Quote patterns to prevent caller-shell expansion.

Acceptance: repeated patterns exclude their union; default selection is unchanged; unusual filenames remain intact; missing/empty patterns return 2; excluded corrupt inputs never reach processing; excluded sources remain present under deletion options. Reject exclusions for directory-level and whole-album tools to prevent filtered directories becoming cleanup candidates. Custom CLIs and MCP arguments do not gain this flag.

Sources and existing verification/publication/deletion contracts remain unchanged. `--` ends shared option parsing. No version tag or release is requested.
