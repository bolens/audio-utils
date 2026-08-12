#!/usr/bin/env bash

convert_one() {
  local marker=$1 dir key snapshot baseline drift
  dir=$(dirname -- "$marker")
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would archive-audit: $dir"
    return 0
  fi
  if [[ "${ARCHIVE_AUDIT_QUICK:-0}" -eq 1 ]]; then
    archive_package_verify "$dir" || { log_fail "$dir" "archive verification failed"; return 1; }
  else
    archive_package_audit "$dir" || { log_fail "$dir" "archive semantic/integrity audit failed"; return 1; }
  fi

  key=$(au_sha256_str "$(au_abspath "$dir")")
  if [[ -n "${ARCHIVE_AUDIT_SNAPSHOT_DIR:-}" ]]; then
    snapshot="$ARCHIVE_AUDIT_SNAPSHOT_DIR/$key.tsv"
    case "$(au_abspath "$snapshot")" in "$dir"/*)
      log_fail "$dir" "snapshot directory must be outside package"
      return 1
      ;;
    esac
    archive_snapshot_write "$dir" "$snapshot" || { log_fail "$dir" "snapshot write failed"; return 1; }
  fi
  if [[ -n "${ARCHIVE_AUDIT_BASELINE_DIR:-}" ]]; then
    baseline="$ARCHIVE_AUDIT_BASELINE_DIR/$key.tsv"
    snapshot=$(audio_utils_mktemp "archive-current.XXXXXX") || return 1
    archive_snapshot_write "$dir" "$snapshot" || return 1
    if ! drift=$(archive_snapshot_compare "$baseline" "$snapshot"); then
      log_fail "$dir" "archive baseline drift" "baseline=$baseline;${drift//$'\n'/|}"
      return 1
    fi
  fi
  log_progress "ok: $dir"
  log_success "$dir" "clean" "" "$(file_sha256 "$marker")" "package-ok"
}
