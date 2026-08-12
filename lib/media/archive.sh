#!/usr/bin/env bash
# Preservation-package verification shared by converters and archive-audit.

archive_package_verify() {
  local dir=$1 recorded actual
  local -a mini_args=(-Vm "$dir/SHA256SUMS" -x "$dir/SHA256SUMS.minisig")
  [[ -d "$dir" && -s "$dir/SHA256SUMS" && -s "$dir/ARCHIVE_COMPLETE.json" ]] || return 1
  recorded=$(sed -n 's/.*"sha256sums":"\([0-9a-f]\{64\}\)".*/\1/p' \
    "$dir/ARCHIVE_COMPLETE.json")
  actual=$(file_sha256 "$dir/SHA256SUMS")
  [[ -n "$recorded" && "$recorded" == "$actual" ]] || return 1
  (cd -- "$dir" && sha256sum -c --quiet SHA256SUMS) || return 1
  if [[ -f "$dir/SHA256SUMS.minisig" ]]; then
    command -v minisign >/dev/null 2>&1 || return 1
    [[ -n "${AUDIO_UTILS_ARCHIVE_PUBKEY:-${AUDIO_UTILS_BD_SIGN_PUBKEY:-}}" ]] && \
      mini_args+=(-P "${AUDIO_UTILS_ARCHIVE_PUBKEY:-$AUDIO_UTILS_BD_SIGN_PUBKEY}")
    minisign "${mini_args[@]}" >/dev/null || return 1
  fi
}

archive_manifest_verify() {
  local dir=$1 manifest="$1/provenance/archive-manifest.jsonl"
  local f rel encoded line sha md5 samples count=0 records
  [[ -s "$manifest" ]] || return 1
  while IFS= read -r -d '' f; do
    rel=${f#"$dir"/}
    encoded=$(json_str "$rel")
    line=$(grep -F '"flac":'"$encoded" "$manifest" | tail -n1) || return 1
    [[ -n "$line" ]] || return 1
    sha=$(sed -n 's/.*"sha256":"\([0-9a-f]\{64\}\)".*/\1/p' <<<"$line")
    md5=$(sed -n 's/.*"audio_md5":"\([0-9a-f]\{32\}\)".*/\1/p' <<<"$line")
    samples=$(sed -n 's/.*"samples":\([0-9][0-9]*\).*/\1/p' <<<"$line")
    [[ "$sha" == "$(file_sha256 "$f")" && "$md5" == "$(audio_md5 "$f")" && \
      "$samples" == "$(audio_samples "$f")" ]] || return 1
    ((count++)) || true
  done < <(find -P "$dir" -type f -name '*.flac' -print0)
  records=$(grep -c '"flac":' "$manifest" || true)
  ((count > 0 && records == count))
}

archive_preserved_streams_verify() {
  local dir=$1 source flac codec expected
  while IFS= read -r -d '' source; do
    flac=${source%.source.mka}
    [[ -f "$flac" ]] || return 1
    codec=$(audio_codec "$source")
    expected=$(metaflac --show-tag=SOURCE_CODEC -- "$flac" 2>/dev/null)
    expected=${expected#SOURCE_CODEC=}
    [[ -n "$codec" && "$codec" == "$expected" ]] || return 1
  done < <(find -P "$dir" -type f -name '*.source.mka' -print0)
}

archive_package_audit() {
  local dir=$1 f decoded stored fail=0
  archive_package_verify "$dir" || fail=1
  archive_manifest_verify "$dir" || fail=1
  archive_preserved_streams_verify "$dir" || fail=1
  while IFS= read -r -d '' f; do
    flac -t --silent "$f" || fail=1
    decoded=$(audio_md5 "$f")
    stored=$(metaflac --show-md5sum -- "$f" 2>/dev/null)
    [[ -n "$decoded" && "$decoded" == "$stored" ]] || fail=1
  done < <(find -P "$dir" -type f -name '*.flac' -print0)
  if [[ -f "$dir/archive.par2" ]]; then
    command -v par2 >/dev/null 2>&1 && \
      par2 verify "$dir/archive.par2" >/dev/null || fail=1
  fi
  ((fail == 0))
}

archive_snapshot_write() {
  local dir=$1 output=$2 tmp f rel
  mkdir -p -- "$(dirname -- "$output")" || return 1
  tmp=$(mktemp --tmpdir="$(dirname -- "$output")" .archive-snapshot.XXXXXX) || return 1
  {
    printf '# audio_utils=%s policy=archive-v1\n' "$(audio_utils_version)"
    printf 'sha256\tbytes\tpath\n'
    while IFS= read -r -d '' f; do
      rel=${f#"$dir"/}
      printf '%s\t%s\t%s\n' "$(file_sha256 "$f")" "$(file_bytes "$f")" "$rel"
    done < <(find -P "$dir" -type f -print0 | LC_ALL=C sort -z)
  } >"$tmp"
  mv -f -- "$tmp" "$output" || { rm -f -- "$tmp"; return 1; }
}

archive_snapshot_compare() {
  local baseline=$1 current=$2
  [[ -s "$baseline" && -s "$current" ]] || return 1
  diff -u -- "$baseline" "$current"
}
