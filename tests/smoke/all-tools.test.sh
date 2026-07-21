#!/usr/bin/env bash
# Smoke tests over every tool: --help exits 0, a bad flag exits 2, and a
# dry run over an empty directory succeeds without writing state.
# Data-driven: tools are discovered the same way the root Makefile does.
# covers: lib/load.sh lib/plugin_init.sh lib/cli/cli.sh lib/cli/convert_all.sh
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

# tool dir → entry script path (<dir>/<toolname>.sh)
# AU_SMOKE_ONLY narrows to a single tool (per-tool `make test`).
_tools() {
  local mk
  for mk in "$AU_REPO_ROOT"/conversion/*/Makefile "$AU_REPO_ROOT"/util/*/*/Makefile; do
    [[ -f "$mk" ]] || continue
    local d=${mk%/Makefile}
    if [[ -n "${AU_SMOKE_ONLY:-}" && "${d##*/}" != "$AU_SMOKE_ONLY" ]]; then
      continue
    fi
    printf '%s/%s.sh\n' "$d" "${d##*/}"
  done
}

test_every_tool_has_entry_script() {
  local entry missing=0
  while IFS= read -r entry; do
    if [[ ! -x "$entry" ]]; then
      echo "missing or not executable: ${entry#"$AU_REPO_ROOT"/}" >&2
      ((++missing))
    fi
  done < <(_tools)
  [[ "$missing" -eq 0 ]] || fail "$missing tool(s) without entry script"
}

test_help_exits_zero() {
  local entry rc bad=0
  while IFS= read -r entry; do
    rc=0
    "$entry" --help >/dev/null 2>&1 <&- || rc=$?
    if [[ "$rc" -ne 0 ]]; then
      echo "--help rc=$rc: ${entry#"$AU_REPO_ROOT"/}" >&2
      ((++bad))
    fi
  done < <(_tools)
  [[ "$bad" -eq 0 ]] || fail "$bad tool(s) fail --help"
}

test_help_prints_usage() {
  local entry out bad=0
  while IFS= read -r entry; do
    out=$("$entry" --help 2>&1 <&- || true)
    if [[ -z "$out" ]]; then
      echo "--help produced no output: ${entry#"$AU_REPO_ROOT"/}" >&2
      ((++bad))
    fi
  done < <(_tools)
  [[ "$bad" -eq 0 ]] || fail "$bad tool(s) print empty --help"
}

test_bad_flag_exits_two() {
  local entry rc bad=0
  while IFS= read -r entry; do
    rc=0
    "$entry" -% >/dev/null 2>&1 <&- || rc=$?
    if [[ "$rc" -ne 2 ]]; then
      echo "bad flag rc=$rc (want 2): ${entry#"$AU_REPO_ROOT"/}" >&2
      ((++bad))
    fi
  done < <(_tools)
  [[ "$bad" -eq 0 ]] || fail "$bad tool(s) mishandle bad flags"
}

# Dry run over an empty dir: exit 0 ("nothing to do") and leave no state
# files behind. Tools whose dependencies are missing are counted as skipped.
# The three disc tools take a device/disc dir, not a music dir — a dry run
# on an empty dir legitimately exits non-zero there, so they are exempt.
test_dry_run_empty_dir_is_clean() {
  local entry rc bad=0 skipped=0 name out
  local empty="$T/empty-library" other="$T/other-root"
  export XDG_STATE_HOME="$T/state"
  mkdir -p "$empty" "$other"

  # Tools with mandatory long options beyond the shared flag set.
  local -A extra_args=(
    [library-prune]="--flac-root=$other"
    [library-sync]="--portable-root=$other"
    [tree-diff]="--against=$other"
    [playlist-export]="--dest=$T/export-dest"
    [tags-lookup]="--client-key=testkey"
  )

  while IFS= read -r entry; do
    name=${entry##*/}
    name=${name%.sh}
    case "$name" in
      dvd-to-flac | bluray-to-flac | cdda-to-flac) continue ;;
    esac
    rc=0
    # shellcheck disable=SC2086  # extra_args values are single flags
    out=$("$entry" -n ${extra_args[$name]:-} "$empty" 2>&1 <&-) || rc=$?
    if [[ "$rc" -eq 2 ]] && grep -Eq \
      'missing required command|lacks encoder|AUDIO_UTILS_TAKC' <<<"$out"; then
      ((++skipped))
      continue
    fi
    if [[ "$rc" -ne 0 ]]; then
      echo "dry-run rc=$rc: ${entry#"$AU_REPO_ROOT"/}: $(tail -1 <<<"$out")" >&2
      ((++bad))
    fi
  done < <(_tools)

  if [[ -d "$XDG_STATE_HOME" ]]; then
    local stray
    stray=$(find "$XDG_STATE_HOME" -type f | head -5)
    [[ -z "$stray" ]] || fail "dry run wrote state files:"$'\n'"$stray"
  fi
  echo "dry-run: skipped $skipped tool(s) with missing deps" >&2
  [[ "$bad" -eq 0 ]] || fail "$bad tool(s) fail empty dry-run"
}

run_tests
