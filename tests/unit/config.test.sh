#!/usr/bin/env bash
# Unit tests: lib/core/config.sh (XDG config loader).
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

_load_lib() {
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/log.sh"
  # shellcheck source=/dev/null
  source "$AU_REPO_ROOT/lib/core/config.sh"
}

_write_config() {
  mkdir -p "$XDG_CONFIG_HOME/audio-utils"
  cat >"$XDG_CONFIG_HOME/audio-utils/config"
}

test_config_missing_file_is_ok() {
  _load_lib
  audio_utils_load_config
}

test_config_sets_allowed_key() {
  _load_lib
  _write_config <<<'AUDIO_UTILS_ROOTS=/music'
  audio_utils_load_config
  assert_eq "${AUDIO_UTILS_ROOTS:-}" "/music"
}

test_config_env_wins_over_file() {
  _load_lib
  _write_config <<<'AUDIO_UTILS_ROOTS=/from-file'
  export AUDIO_UTILS_ROOTS=/from-env
  audio_utils_load_config
  assert_eq "$AUDIO_UTILS_ROOTS" "/from-env"
}

test_config_rejects_unknown_key() {
  _load_lib
  _write_config <<'EOF'
NOT_ALLOWED=oops
PATH=/pwned
AUDIO_UTILS_MP3_QUALITY=v2
EOF
  audio_utils_load_config 2>"$T/err.txt"
  assert_eq "${NOT_ALLOWED:-unset}" "unset" "unknown key must not be set"
  assert_grep "ignoring invalid config line" "$T/err.txt"
  assert_eq "${AUDIO_UTILS_MP3_QUALITY:-}" "v2" "valid key still applies"
}

test_config_legacy_wav2flac_roots_accepted() {
  _load_lib
  _write_config <<<'WAV2FLAC_ROOTS=/legacy'
  audio_utils_load_config
  assert_eq "${WAV2FLAC_ROOTS:-}" "/legacy"
}

test_config_strips_quotes_and_expands_home() {
  _load_lib
  _write_config <<'EOF'
AUDIO_UTILS_ROOTS="$HOME/Music"
AUDIO_UTILS_TAKC='~/bin/takc'
EOF
  audio_utils_load_config
  assert_eq "${AUDIO_UTILS_ROOTS:-}" "$HOME/Music"
  assert_eq "${AUDIO_UTILS_TAKC:-}" "$HOME/bin/takc"
}

test_config_comments_and_blank_lines() {
  _load_lib
  _write_config <<'EOF'

# a comment
AUDIO_UTILS_ROOTS=/music   # trailing comment
EOF
  audio_utils_load_config 2>"$T/err.txt"
  assert_eq "${AUDIO_UTILS_ROOTS:-}" "/music"
  assert_eq "$(cat "$T/err.txt")" "" "no warnings expected"
}

run_tests
