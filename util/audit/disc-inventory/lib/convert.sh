#!/usr/bin/env bash
# Inventory one marker file as a disc/CUE unit (dedupe VIDEO_TS).

_disc_record() {
  local kind=$1 path=$2
  local rows="${AU_DISCINV_STATE:?}/units.tsv" lock="${AU_DISCINV_STATE}/units.lock"
  (
    flock 9
    printf '%s\t%s\n' "$kind" "$path" >>"$rows"
  ) 9>"$lock"
}

convert_one() {
  local src="$1" dir parent kind key lock done_f base

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would inventory: $src"; return 0
  fi

  base=$(basename -- "$src")
  dir=$(dirname -- "$src")

  case "${base,,}" in
    *.cue)
      kind=cue
      parent=$dir
      ;;
    index.bdmv)
      kind=bdmv
      parent=$(dirname -- "$dir")
      ;;
    video_ts.ifo|*.ifo)
      kind=video_ts
      parent=$(dirname -- "$dir")
      # Dedupe: only first IFO in this VIDEO_TS
      key=$(au_sha256_str "$dir")
      lock="${AU_DISCINV_STATE:?}/$key.lock"
      done_f="${AU_DISCINV_STATE}/$key.done"
      if ! (
        flock 9
        if [[ -f "$done_f" ]]; then exit 1; fi
        printf '1\n' >"$done_f"
        exit 0
      ) 9>"$lock"; then
        log_progress "skip (VIDEO_TS already counted): $dir"
        log_success "$src" "video_ts" "" "" "deduped"
        return 0
      fi
      ;;
    *)
      log_progress "skip: $src"
      return 0
      ;;
  esac

  _disc_record "$kind" "$parent"
  log_progress "found $kind: $parent"
  log_success "$src" "$kind" "" "$(file_sha256 "$src" 2>/dev/null || true)" "path=$parent"
}
