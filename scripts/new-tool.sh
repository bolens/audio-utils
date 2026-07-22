#!/usr/bin/env bash
# Scaffold a new audio-utils tool: full skeleton, zero edits needed outside
# the new directory (root Makefile + CI auto-discover dirs with a Makefile).
#
# Usage:
#   scripts/new-tool.sh util CATEGORY NAME [SRC_EXT]
#   scripts/new-tool.sh converter X-to-Y
#
#   util       creates util/CATEGORY/NAME (SRC_EXT default: flac)
#   converter  creates conversion/X-to-Y (source ext X, dest ext Y)
#
# Prints remaining manual steps (README table row, docs, tests) when done.
set -euo pipefail

die() { echo "new-tool: $*" >&2; exit 2; }

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

KIND="${1:-}"
case "$KIND" in
  util)
    CATEGORY="${2:-}"
    NAME="${3:-}"
    SRC_EXT="${4:-flac}"
    DEST_EXT="$SRC_EXT"
    [[ -n "$CATEGORY" && -n "$NAME" ]] || die "usage: new-tool.sh util CATEGORY NAME [SRC_EXT]"
    TOOL_DIR="util/$CATEGORY/$NAME"
    # Depth of the tool dir below the repo root, for shellcheck source= hints.
    LIB_UP="../../.."
    ;;
  converter)
    NAME="${2:-}"
    [[ "$NAME" == *-to-* ]] || die "usage: new-tool.sh converter X-to-Y"
    SRC_EXT="${NAME%%-to-*}"
    DEST_EXT="${NAME##*-to-}"
    TOOL_DIR="conversion/$NAME"
    LIB_UP="../.."
    ;;
  *)
    die "usage: new-tool.sh util CATEGORY NAME [SRC_EXT] | new-tool.sh converter X-to-Y"
    ;;
esac

[[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "NAME must be lowercase-kebab: $NAME"
[[ ! -e "$REPO_ROOT/$TOOL_DIR" ]] || die "already exists: $TOOL_DIR"

WORKDIR_PREFIX=${NAME//-/}
FIND_SCRIPT="find-${SRC_EXT}-dirs.sh"

mkdir -p "$REPO_ROOT/$TOOL_DIR/lib"
cd "$REPO_ROOT/$TOOL_DIR"

# subst FILE - replace __TOKEN__ placeholders in a freshly written template.
subst() {
  sed -i \
    -e "s|__NAME__|$NAME|g" \
    -e "s|__SRC_EXT__|$SRC_EXT|g" \
    -e "s|__DEST_EXT__|$DEST_EXT|g" \
    -e "s|__WORKDIR_PREFIX__|$WORKDIR_PREFIX|g" \
    -e "s|__FIND_SCRIPT__|$FIND_SCRIPT|g" \
    -e "s|__LIB_UP__|$LIB_UP|g" \
    "$1"
}

# --- entry script -------------------------------------------------------------

cat >"$NAME.sh" <<'EOF'
#!/usr/bin/env bash
# __NAME__ - TODO: one-line description.
#
# Usage:
#   __NAME__.sh DIR [DIR ...]
#   __FIND_SCRIPT__ | __NAME__.sh
#
# Options:
#   -f FILE  -L FILE  -S FILE  -n  -j N  -q  -v  -h  --version
#
# Exit codes: 0 ok, 1 failures, 2 usage/deps

set -euo pipefail
AU_USAGE_START=2
AU_USAGE_END=10
AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=__LIB_UP__/lib/cli/cli.sh
source "$AU_ROOT/lib/cli/cli.sh"
audio_utils_cli_run "$@"
EOF
subst "$NAME.sh"

# --- find-dirs shim -----------------------------------------------------------

cat >"$FIND_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_ROOT=$SCRIPT_DIR
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
exec "${AU_ROOT}/lib/cli/find-audio-dirs.sh" --ext __SRC_EXT__ "$@"
EOF
subst "$FIND_SCRIPT"

# --- convert-all shim -----------------------------------------------------------

cat >convert-all.sh <<'EOF'
#!/usr/bin/env bash
# Find __SRC_EXT__ dirs and run __NAME__. Extra args go to __NAME__.sh.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
AU_ROOT=$SCRIPT_DIR
while [[ ! -f "$AU_ROOT/lib/plugin_init.sh" ]]; do
  [[ "$AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; exit 2; }
  AU_ROOT=$(dirname "$AU_ROOT")
done
# shellcheck source=__LIB_UP__/lib/load.sh
source "${AU_ROOT}/lib/load.sh"
audio_utils_load_config
audio_utils_convert_all \
  "${SCRIPT_DIR}/__FIND_SCRIPT__" \
  "${SCRIPT_DIR}/__NAME__.sh" \
  "__SRC_EXT__" \
  "$@"
EOF
subst convert-all.sh

# --- plugin -------------------------------------------------------------------

cat >lib/plugin.sh <<'EOF'
#!/usr/bin/env bash
# __NAME__ plugin - TODO: one-line description.

AU_TOOL_NAME="${AU_TOOL_NAME:-__NAME__}"
AU_SOURCE_EXT=__SRC_EXT__
AU_DEST_EXT=__DEST_EXT__
AU_DISK_FACTOR=1.5
AU_WORKDIR_PREFIX=__WORKDIR_PREFIX__
AU_SUCCESS_COLUMNS='timestamp,src,dest,audio_md5,dest_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA=""

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=__LIB_UP__/../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

plugin_require_deps() {
  require_cmds flock
}

plugin_banner_extra() {
  log_always "mode:      TODO describe"
}

plugin_export_env() {
  :
}
EOF
subst lib/plugin.sh

# --- convert stub ---------------------------------------------------------------

cat >lib/convert.sh <<'EOF'
#!/usr/bin/env bash
# __NAME__ - process one file. Runs in a worker; log_* and the shared
# helpers (audio_md5, file_sha256, make_workdir, …) are available.
#
# For a standard lossy/PCM pipeline, delete this file and wire the shared
# pipeline in plugin.sh instead (see conversion/flac-to-mp3/lib/plugin.sh:
# lossy_plugin_wire + lib/pipeline/lossy_hooks.sh).

convert_one() {
  local src="$1"

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would process: $src"
    return 0
  fi

  # TODO: real work here.
  log_fail "$src" "__NAME__ not implemented"
  return 1
}
EOF
subst lib/convert.sh

# --- Makefile -----------------------------------------------------------------

cat >Makefile <<'EOF'
# __NAME__
TOOL = __NAME__
SCRIPTS = __NAME__.sh __FIND_SCRIPT__ convert-all.sh lib/*.sh
FIND_SCRIPT = __FIND_SCRIPT__
WORKDIR_GLOB = .__WORKDIR_PREFIX__.*
HAS_CONVERT_VERBOSE = 1
AU_ROOT := $(shell d="$(CURDIR)"; while [ ! -f "$$d/lib/tool.mk" ] && [ "$$d" != / ]; do d=$$(dirname "$$d"); done; echo "$$d")
include $(AU_ROOT)/lib/tool.mk
EOF
subst Makefile

# --- .shellcheckrc --------------------------------------------------------------

cat >.shellcheckrc <<'EOF'
# Project shellcheck config.
source-path=SCRIPTDIR
source-path=lib
source-path=../../lib
source-path=../../lib/cli
source-path=../../../lib
source-path=../../../lib/cli
external-sources=true
shell=bash
disable=SC1093
EOF

# --- README ---------------------------------------------------------------------

REL_ROOT=$LIB_UP
cat >README.md <<EOF
# $NAME

TODO: what this tool does, when to use it, examples.

Part of **[audio-utils]($REL_ROOT/)**.

\`\`\`bash
./$NAME.sh -n DIR     # dry run
./$NAME.sh DIR
make help
\`\`\`
EOF

chmod +x "$NAME.sh" "$FIND_SCRIPT" convert-all.sh

echo "Created $TOOL_DIR/"
find . -type f | sort | sed 's|^\./|  |'
echo
echo "Remaining manual steps:"
echo "  1. Implement lib/convert.sh convert_one (or wire a shared pipeline in lib/plugin.sh)"
echo "  2. Fill in the usage block in $NAME.sh (keep AU_USAGE_START/END in sync)"
echo "  3. Add a row to the root README.md tool table"
echo "  4. Note any new dependencies in docs/requirements.md"
echo "  5. Add a functional test in tests/functional/ (make test must stay green)"
echo
echo "Verify: make -C $TOOL_DIR check && make -C $TOOL_DIR test"
