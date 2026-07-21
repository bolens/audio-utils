#!/usr/bin/env bash
# Audit functional-test coverage across tools and lib modules.
#
# Every tool gets smoke coverage automatically (tests/smoke/all-tools.test.sh);
# this script tracks the stronger bar: at least one functional test that
# exercises the tool's actual behavior, and direct unit/functional coverage
# for shared lib modules.
#
# Tools that cannot be tested without specific hardware, network services, or
# proprietary encoders live in tests/coverage-exempt.tsv with a reason. They
# are excluded from the goal denominator but always listed so the exemptions
# themselves stay under review (stale or shadowed entries are flagged).
#
# Lib detection: a module counts as directly covered when its repo-relative
# path appears anywhere in tests/ — either a real `source` line or a
# declarative marker in a test that exercises it through tools:
#   # covers: lib/cli/driver.sh lib/core/success_log.sh
#
# Usage:
#   scripts/coverage-audit.sh [--goal PCT] [-q] [--list WHAT]
#
#   --goal PCT    Coverage goal percent (default: 90)
#   -q            Summary only (no burn-down / exemption tables)
#   --list WHAT   Machine-readable paths, one per line, then exit.
#                 WHAT: uncovered | covered | exempt | lib-uncovered
#
# Exit codes: 0 goal met, 1 goal missed (or stale exemptions), 2 usage

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
EXEMPT_FILE="$ROOT/tests/coverage-exempt.tsv"
GOAL=90
QUIET=0
LIST=""

usage() {
  sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

while (($# > 0)); do
  case "$1" in
    --goal)
      [[ -n "${2:-}" ]] || usage
      GOAL=$2
      shift 2
      ;;
    --goal=*)
      GOAL=${1#--goal=}
      shift
      ;;
    --list)
      [[ -n "${2:-}" ]] || usage
      LIST=$2
      shift 2
      ;;
    --list=*)
      LIST=${1#--list=}
      shift
      ;;
    -q) QUIET=1; shift ;;
    -h | --help) usage 0 ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done
[[ "$GOAL" =~ ^[0-9]+$ ]] || { echo "--goal must be an integer" >&2; exit 2; }

cd "$ROOT"

# --- exemptions ---------------------------------------------------------------

declare -A EXEMPT_REASON=()
if [[ -f "$EXEMPT_FILE" ]]; then
  while IFS=$'\t' read -r path reason || [[ -n "$path" ]]; do
    [[ -z "$path" || "$path" == \#* ]] && continue
    EXEMPT_REASON["$path"]=${reason:-"(no reason given)"}
  done <"$EXEMPT_FILE"
fi

# --- tool classification --------------------------------------------------------

# A tool is functionally covered when its name appears in any functional test.
_tool_covered() { # tool-name
  grep -rql -- "$1" tests/functional/ 2>/dev/null
}

_tool_loc() { # tool-dir
  cat "$1"/*.sh "$1"/lib/*.sh 2>/dev/null | wc -l
}

declare -a COVERED=() UNCOVERED=() EXEMPTED=() SHADOWED=() STALE=()
declare -A SEEN_EXEMPT=()

for mk in conversion/*/Makefile util/*/*/Makefile; do
  [[ -f "$mk" ]] || continue
  dir=${mk%/Makefile}
  name=${dir##*/}
  if [[ -n "${EXEMPT_REASON[$dir]:-}" ]]; then
    SEEN_EXEMPT["$dir"]=1
    if _tool_covered "$name"; then
      SHADOWED+=("$dir")   # exempt but a functional test names it — retire entry?
    fi
    EXEMPTED+=("$dir")
  elif _tool_covered "$name"; then
    COVERED+=("$dir")
  else
    UNCOVERED+=("$dir")
  fi
done

# Exempt entries pointing at tools/libs that no longer exist.
for path in "${!EXEMPT_REASON[@]}"; do
  [[ -n "${SEEN_EXEMPT[$path]:-}" ]] && continue
  [[ -f "$path" || -d "$path" ]] || STALE+=("$path")
done

# --- lib classification -----------------------------------------------------------

# A lib module is directly covered when a test references its repo-relative
# path — via a source line or a "# covers:" marker. Everything else is
# exercised only indirectly through tool entry points.
declare -a LIB_DIRECT=() LIB_INDIRECT=() LIB_EXEMPT=()
for f in lib/*.sh lib/*/*.sh; do
  [[ -f "$f" ]] || continue
  if [[ -n "${EXEMPT_REASON[$f]:-}" ]]; then
    SEEN_EXEMPT["$f"]=1
    LIB_EXEMPT+=("$f")
  elif grep -rql -- "$f" tests/ 2>/dev/null; then
    LIB_DIRECT+=("$f")
  else
    LIB_INDIRECT+=("$f")
  fi
done

# --- machine-readable lists --------------------------------------------------------

if [[ -n "$LIST" ]]; then
  case "$LIST" in
    uncovered) ((${#UNCOVERED[@]} == 0)) || printf '%s\n' "${UNCOVERED[@]}" ;;
    covered) ((${#COVERED[@]} == 0)) || printf '%s\n' "${COVERED[@]}" ;;
    exempt) ((${#EXEMPTED[@]} == 0)) || printf '%s\n' "${EXEMPTED[@]}" ;;
    lib-uncovered) ((${#LIB_INDIRECT[@]} == 0)) || printf '%s\n' "${LIB_INDIRECT[@]}" ;;
    *) echo "unknown --list: $LIST (uncovered|covered|exempt|lib-uncovered)" >&2; exit 2 ;;
  esac
  exit 0
fi

# --- report -----------------------------------------------------------------------

total=$((${#COVERED[@]} + ${#UNCOVERED[@]} + ${#EXEMPTED[@]}))
denom=$((total - ${#EXEMPTED[@]}))
pct=$(awk -v c="${#COVERED[@]}" -v d="$denom" \
  'BEGIN { printf "%.1f", (d > 0) ? c * 100 / d : 0 }')
raw_pct=$(awk -v c="${#COVERED[@]}" -v t="$total" \
  'BEGIN { printf "%.1f", (t > 0) ? c * 100 / t : 0 }')
test_files=$(find tests/unit tests/smoke tests/functional -name '*.test.sh' | wc -l)
test_fns=$(grep -rhc '^test_[a-z_]*()' tests/*/*.test.sh 2>/dev/null \
  | awk '{s += $1} END {print s}')

echo "audio-utils coverage audit"
echo "=========================="
echo ""
printf 'Tools: %d total   test files: %d   test functions: %d\n' \
  "$total" "$test_files" "$test_fns"
printf '  functionally covered:  %3d\n' "${#COVERED[@]}"
printf '  exempt (hard to test): %3d\n' "${#EXEMPTED[@]}"
printf '  uncovered:             %3d\n' "${#UNCOVERED[@]}"
echo ""
printf 'Coverage: %s%% of testable tools (%d/%d, goal %d%%)   raw: %s%% of all tools\n' \
  "$pct" "${#COVERED[@]}" "$denom" "$GOAL" "$raw_pct"
printf 'Lib modules: %d directly covered, %d indirect-only, %d exempt\n' \
  "${#LIB_DIRECT[@]}" "${#LIB_INDIRECT[@]}" "${#LIB_EXEMPT[@]}"

if [[ "$QUIET" -eq 0 ]]; then
  if ((${#UNCOVERED[@]} > 0)); then
    echo ""
    echo "Burn-down (uncovered tools, largest first):"
    for dir in "${UNCOVERED[@]}"; do
      printf '%6d loc  %s\n' "$(_tool_loc "$dir")" "$dir"
    done | sort -rn
  fi

  if ((${#LIB_INDIRECT[@]} > 0)); then
    echo ""
    echo "Lib modules without direct test coverage (exercised via tools only):"
    for f in "${LIB_INDIRECT[@]}"; do
      printf '%6d loc  %s\n' "$(wc -l <"$f")" "$f"
    done | sort -rn
  fi

  if ((${#EXEMPTED[@]} > 0 || ${#LIB_EXEMPT[@]} > 0)); then
    echo ""
    echo "Exempt — hard to test without hardware / network / proprietary tools:"
    for path in "${EXEMPTED[@]}" "${LIB_EXEMPT[@]}"; do
      printf '  %-32s %s\n' "$path" "${EXEMPT_REASON[$path]}"
    done | sort
  fi
fi

rc=0
if ((${#SHADOWED[@]} > 0)); then
  echo ""
  echo "WARNING: exempt entries that now have functional coverage (retire them?):"
  printf '  %s\n' "${SHADOWED[@]}"
fi
if ((${#STALE[@]} > 0)); then
  echo ""
  echo "ERROR: stale exempt entries (path no longer exists):"
  printf '  %s\n' "${STALE[@]}"
  rc=1
fi

echo ""
if awk -v p="$pct" -v g="$GOAL" 'BEGIN { exit !(p + 0 >= g) }'; then
  echo "RESULT: goal met (${pct}% >= ${GOAL}%)"
else
  echo "RESULT: goal missed (${pct}% < ${GOAL}%)"
  rc=1
fi
exit "$rc"
