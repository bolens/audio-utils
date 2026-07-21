#!/usr/bin/env bash
# Test runner — discovers and runs tests/**/*.test.sh.
#
# Usage:
#   tests/run.sh [OPTIONS] [TIER|FILE ...]
#
#   TIER          unit | smoke | functional (default: all tiers)
#   -j N          parallel test files (default: nproc)
#   -k FILTER     only run test files whose path matches *FILTER*;
#                 also narrows test_* functions inside files
#   --tool NAME   per-tool run: smoke tier narrowed to NAME plus any
#                 test files whose path matches *NAME*
#   --list        list matching test files and exit
#   -h            this help
#
# Each test file runs in its own process with HOME and all XDG dirs
# redirected into a throwaway sandbox, so tests never touch real state.
# Exit codes: 0 all pass (skips ok), 1 failures, 2 usage.

set -euo pipefail

TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_REPO_ROOT=$(cd "$TESTS_DIR/.." && pwd)
export AU_REPO_ROOT

JOBS=$(nproc 2>/dev/null || echo 4)
FILTER=""
TOOL_ONLY=""
LIST=0
declare -a SELECTORS=()

usage() {
  sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
  exit "${1:-0}"
}

while (($# > 0)); do
  case "$1" in
    -j) [[ -n "${2:-}" ]] || usage 2; JOBS=$2; shift 2 ;;
    -k) [[ -n "${2:-}" ]] || usage 2; FILTER=$2; shift 2 ;;
    --tool) [[ -n "${2:-}" ]] || usage 2; TOOL_ONLY=$2; shift 2 ;;
    --list) LIST=1; shift ;;
    -h|--help) usage 0 ;;
    -*) echo "unknown option: $1" >&2; usage 2 ;;
    *) SELECTORS+=("$1"); shift ;;
  esac
done

[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo "-j must be a positive integer" >&2; exit 2; }

# --- collect test files -------------------------------------------------------

declare -a FILES=()
if ((${#SELECTORS[@]} == 0)); then
  SELECTORS=(unit smoke functional)
fi
for sel in "${SELECTORS[@]}"; do
  if [[ -f "$sel" ]]; then
    FILES+=("$sel")
  elif [[ -d "$TESTS_DIR/$sel" ]]; then
    while IFS= read -r f; do FILES+=("$f"); done \
      < <(find "$TESTS_DIR/$sel" -name '*.test.sh' | sort)
  elif [[ -d "$sel" ]]; then
    while IFS= read -r f; do FILES+=("$f"); done \
      < <(find "$sel" -name '*.test.sh' | sort)
  else
    echo "no such tier/file: $sel" >&2
    exit 2
  fi
done

if [[ -n "$TOOL_ONLY" ]]; then
  # Keep smoke files (narrowed to the tool via AU_SMOKE_ONLY) plus any
  # test file naming the tool.
  declare -a KEPT=()
  for f in "${FILES[@]}"; do
    if [[ "$f" == */smoke/* || "$f" == *"$TOOL_ONLY"* ]]; then
      KEPT+=("$f")
    fi
  done
  FILES=("${KEPT[@]}")
  export AU_SMOKE_ONLY="$TOOL_ONLY"
fi

if [[ -n "$FILTER" ]]; then
  declare -a KEPT=()
  for f in "${FILES[@]}"; do
    [[ "$f" == *"$FILTER"* ]] && KEPT+=("$f")
  done
  # Filter may name test functions rather than files: keep all files and
  # let the harness narrow, if no file path matched.
  if ((${#KEPT[@]} > 0)); then
    FILES=("${KEPT[@]}")
  else
    export AU_TEST_FILTER="$FILTER"
  fi
fi

if ((${#FILES[@]} == 0)); then
  echo "no test files found" >&2
  exit 2
fi

if ((LIST)); then
  printf '%s\n' "${FILES[@]}"
  exit 0
fi

# --- run ----------------------------------------------------------------------

RUN_TMP=$(mktemp -d "${TMPDIR:-/tmp}/au-tests.XXXXXX")
# shellcheck disable=SC2064  # expand now: path is fixed
trap "rm -rf -- '$RUN_TMP'" EXIT

run_one() { # file → writes <sandbox>/.result and .output
  local file=$1 sb=$2 rc=0
  mkdir -p "$sb"/{home,state,cache,config,runtime,tmp}
  chmod 700 "$sb/runtime"
  env -u AUDIO_UTILS_ROOTS -u WAV2FLAC_ROOTS \
    HOME="$sb/home" \
    XDG_STATE_HOME="$sb/state" \
    XDG_CACHE_HOME="$sb/cache" \
    XDG_CONFIG_HOME="$sb/config" \
    XDG_RUNTIME_DIR="$sb/runtime" \
    TMPDIR="$sb/tmp" \
    AU_REPO_ROOT="$AU_REPO_ROOT" \
    AU_TEST_SANDBOX="$sb" \
    AU_TEST_FILTER="${AU_TEST_FILTER:-}" \
    AU_SMOKE_ONLY="${AU_SMOKE_ONLY:-}" \
    bash "$file" >"$sb/.output" 2>&1 || rc=$?
  echo "$rc" >"$sb/.result"
}

i=0
declare -a SANDBOXES=()
for f in "${FILES[@]}"; do
  sb="$RUN_TMP/$((i++)).$(basename "$f" .test.sh)"
  SANDBOXES+=("$sb")
  run_one "$f" "$sb" &
  while (($(jobs -rp | wc -l) >= JOBS)); do
    wait -n || true
  done
done
wait || true

# --- report -------------------------------------------------------------------

total_pass=0 total_fail=0 total_skip=0 failed_files=0
for idx in "${!FILES[@]}"; do
  f=${FILES[$idx]}
  sb=${SANDBOXES[$idx]}
  rel=${f#"$TESTS_DIR"/}
  rc=$(cat "$sb/.result" 2>/dev/null || echo 1)
  echo "== $rel"
  sed 's/^/   /' "$sb/.output" 2>/dev/null || echo "   (no output)"
  if [[ "$rc" -ne 0 ]]; then
    ((++failed_files))
  fi
  # Tally from the per-file summary line (pass=N fail=N skip=N).
  summary=$(grep -o 'pass=[0-9]* fail=[0-9]* skip=[0-9]*' "$sb/.output" 2>/dev/null | tail -1 || true)
  if [[ "$summary" =~ pass=([0-9]+)\ fail=([0-9]+)\ skip=([0-9]+) ]]; then
    ((total_pass += BASH_REMATCH[1])) || true
    ((total_fail += BASH_REMATCH[2])) || true
    ((total_skip += BASH_REMATCH[3])) || true
  fi
done

echo
echo "=== tests: ${#FILES[@]} files, pass=$total_pass fail=$total_fail skip=$total_skip"
if ((failed_files > 0)); then
  echo "=== FAILED ($failed_files file(s))"
  exit 1
fi
echo "=== OK"
