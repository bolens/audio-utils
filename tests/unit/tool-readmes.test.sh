#!/usr/bin/env bash
# Unit tests: generated tool README references preserve authored documentation.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_make_readme_tree() {
  mkdir -p "$T/repo/conversion/rich-tool" "$T/repo/util"
  cat >"$T/repo/conversion/rich-tool/rich-tool.sh" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == --help ]]; then
  printf '%s\n' 'Rich tool help' 'Options:' '  --new-option  Current behavior'
  exit 0
fi
exit 2
EOF
  chmod +x "$T/repo/conversion/rich-tool/rich-tool.sh"
}

test_sync_preserves_authored_readme_and_is_idempotent() {
  _make_readme_tree
  cat >"$T/repo/conversion/rich-tool/README.md" <<'EOF'
# Rich tool

Long authored guide.

## Design and safety

This content must survive synchronization exactly.
EOF
  cp "$T/repo/conversion/rich-tool/README.md" "$T/authored"

  AU_README_SYNC_ROOT="$T/repo" \
    "$AU_REPO_ROOT/scripts/sync-tool-readmes.sh" >/dev/null
  assert_grep 'Long authored guide.' "$T/repo/conversion/rich-tool/README.md"
  assert_grep -- '--new-option' "$T/repo/conversion/rich-tool/README.md"
  sed '/<!-- BEGIN GENERATED COMMAND REFERENCE -->/,$d' \
    "$T/repo/conversion/rich-tool/README.md" >"$T/preserved"
  # The synchronizer adds one separator newline before the generated block.
  sed -i '${/^$/d;}' "$T/preserved"
  assert_eq "$(cat "$T/preserved")" "$(cat "$T/authored")"

  cp "$T/repo/conversion/rich-tool/README.md" "$T/once"
  AU_README_SYNC_ROOT="$T/repo" \
    "$AU_REPO_ROOT/scripts/sync-tool-readmes.sh" >/dev/null
  cmp -s "$T/once" "$T/repo/conversion/rich-tool/README.md" || \
    fail 'README synchronization is not idempotent'
}

test_sync_refuses_unbalanced_generated_markers() {
  _make_readme_tree
  cat >"$T/repo/conversion/rich-tool/README.md" <<'EOF'
# Rich tool

<!-- BEGIN GENERATED COMMAND REFERENCE -->
Do not discard this trailing authored text.
EOF
  cp "$T/repo/conversion/rich-tool/README.md" "$T/before"
  assert_exit 1 env AU_README_SYNC_ROOT="$T/repo" \
    "$AU_REPO_ROOT/scripts/sync-tool-readmes.sh" 2>/dev/null
  cmp -s "$T/before" "$T/repo/conversion/rich-tool/README.md" || \
    fail 'malformed README was modified'
}

run_tests "$@"
