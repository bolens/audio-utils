#!/usr/bin/env bash
# BDMV / device / decrypted media → per-stream FLAC

_bluray_stream_field() {
  local src="$1" idx="$2" field="$3"
  ffprobe -v error -select_streams "a:$idx" -show_entries "stream=$field" \
    -of default=noprint_wrappers=1:nokey=1 -- "$src" 2>/dev/null | head -n1
}

_bluray_stream_pcm_codec() {
  local src="$1" idx="$2" bits sample_fmt
  bits=$(_bluray_stream_field "$src" "$idx" bits_per_raw_sample)
  [[ "$bits" =~ ^[1-9][0-9]*$ ]] || bits=$(_bluray_stream_field "$src" "$idx" bits_per_sample)
  sample_fmt=$(_bluray_stream_field "$src" "$idx" sample_fmt)
  if [[ "$bits" == 16 || "$sample_fmt" == s16 || "$sample_fmt" == s16p ]]; then
    printf '%s\n' pcm_s16le
  else
    printf '%s\n' pcm_s24le
  fi
}

_bluray_output_path() {
  local src="$1" outdir="$2" source_root="$3" idx="$4" rel rel_dir base
  base=$(basename -- "$src")
  rel=${src#"$source_root"/}
  if [[ "$rel" == "$src" ]]; then
    rel_dir=.
  else
    rel_dir=$(dirname -- "$rel")
  fi
  printf '%s/%s/%s.a%s.flac\n' "$outdir" "$rel_dir" "$base" "$idx"
}

_bluray_dry_run_media() {
  local path="$1" kind="$2" outdir="$3" source_root f n i found=0
  local -a files=()
  if [[ "$kind" == media_file ]]; then
    files+=("$path")
    source_root=$(dirname -- "$path")
  else
    source_root=$path
    au_mapfile0 files < <(bluray_list_plain_media --print0 "$path")
  fi
  for f in "${files[@]}"; do
    n=$(ffprobe -v error -select_streams a -show_entries stream=index \
      -of csv=p=0 -- "$f" 2>/dev/null | grep -c . || true)
    if ((n < 1)); then
      log_err "would fail (no readable audio): $f"
      continue
    fi
    found=1
    for ((i = 0; i < n; i++)); do
      log_info "  -> $(_bluray_output_path "$f" "$outdir" "$source_root" "$i")"
    done
  done
  ((found))
}

_bluray_tag_stream_provenance() {
  local flac="$1" src="$2" idx="$3" field value codec profile lossy=0
  codec=$(_bluray_stream_field "$src" "$idx" codec_name)
  profile=$(_bluray_stream_field "$src" "$idx" profile)
  metaflac --remove-tag=SOURCE_CODEC --remove-tag=SOURCE_PROFILE \
    --remove-tag=SOURCE_LANGUAGE --remove-tag=SOURCE_TITLE \
    --remove-tag=SOURCE_CHANNEL_LAYOUT --remove-tag=LOSSY_SOURCE -- "$flac"
  [[ -n "$codec" ]] && metaflac --set-tag="SOURCE_CODEC=$codec" -- "$flac"
  [[ -n "$profile" ]] && metaflac --set-tag="SOURCE_PROFILE=$profile" -- "$flac"
  for field in language title; do
    value=$(ffprobe -v error -select_streams "a:$idx" \
      -show_entries "stream_tags=$field" -of default=nw=1:nk=1 -- "$src" 2>/dev/null | head -n1)
    [[ -n "$value" ]] && metaflac --set-tag="SOURCE_${field^^}=$value" -- "$flac"
  done
  value=$(_bluray_stream_field "$src" "$idx" channel_layout)
  [[ -n "$value" ]] && metaflac --set-tag="SOURCE_CHANNEL_LAYOUT=$value" -- "$flac"
  case "$codec" in
    aac|ac3|eac3|mp2|mp3|vorbis|opus) lossy=1 ;;
    dts) [[ "${profile,,}" == *"ma"* ]] || lossy=1 ;;
  esac
  if ((lossy)); then
    metaflac --set-tag=LOSSY_SOURCE=1 -- "$flac"
    log_info "note: stream a:$idx uses lossy source codec $codec${profile:+ ($profile)}"
  fi
}

_extract_media_streams() {
  local src="$1" outdir="$2" tmpdir="$3" source_root="$4"
  local base rel rel_dir n i wav flac_out pcm_codec
  local -a enc_out
  local fail=0

  base=$(basename -- "$src")
  rel=${src#"$source_root"/}
  if [[ "$rel" == "$src" ]]; then
    rel_dir=.
  else
    rel_dir=$(dirname -- "$rel")
  fi
  mkdir -p -- "$outdir/$rel_dir" || return 1
  n=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$src" 2>/dev/null | grep -c . || true)
  n=${n:-0}
  ((n >= 1)) || {
    log_fail "$src" "no audio streams"
    return 1
  }

  for ((i = 0; i < n; i++)); do
    flac_out=$(_bluray_output_path "$src" "$outdir" "$source_root" "$i")
    wav="${tmpdir}/${base}.a${i}.wav"
    pcm_codec=$(_bluray_stream_pcm_codec "$src" "$i")

    if [[ -f "$flac_out" && "${OVERWRITE:-0}" -eq 0 ]] && flac_ok "$flac_out"; then
      log_progress "skip (flac ok): $flac_out"
      log_success "$src" "$flac_out" "$(audio_md5 "$flac_out")" "$(file_sha256 "$flac_out")" "skipped-existing-ok;stream=$i"
      continue
    fi

    if ! ffmpeg -v error -y -i "$src" -map "0:a:${i}" -c:a "$pcm_codec" "$wav" 2>"${tmpdir}/ex.err"; then
      set_last_err_file "${tmpdir}/ex.err"
      log_fail "$src" "extract a:$i failed"
      fail=1
      continue
    fi
    if ! encode_flac_verified "$wav" "$tmpdir" "$src#a$i" >"${tmpdir}/enc.out"; then
      log_fail "$src" "encode a:$i failed"
      fail=1
      continue
    fi
    au_mapfile0 enc_out "${tmpdir}/enc.out"
    if ! _bluray_tag_stream_provenance "${enc_out[0]}" "$src" "$i"; then
      log_fail "$src" "tag stream a:$i failed"
      fail=1
      continue
    fi
    mv -f -- "${enc_out[0]}" "$flac_out"
    log_info "verified: $flac_out"
    log_success "$src" "$flac_out" "${enc_out[2]}" "$(file_sha256 "$flac_out")" "converted;stream=$i"
    rm -f -- "$wav" \
      "${tmpdir}/pass1.flac" "${tmpdir}/pass2.flac" "${tmpdir}/pass3.flac" \
      "${tmpdir}/roundtrip.flac" "${tmpdir}/decoded.wav" "${tmpdir}/enc.out" 2>/dev/null || true
  done
  return "$fail"
}

convert_one() {
  local path="$1"
  local outdir tmpdir work media fail=0 kind disc_label source_root

  kind=$(bluray_resolve_input "$path" 2>/dev/null) || kind=unknown
  if [[ "$kind" == unknown ]]; then
    log_fail "$path" "not a BDMV tree, device, or decrypted media"
    return 1
  fi

  case "$kind" in
    bdmv)
      disc_label=$(bluray_disc_root "$path" 2>/dev/null || printf '%s' "$path")
      outdir="${disc_label}/flac"
      ;;
    media_file)
      outdir="$(dirname -- "$path")"
      ;;
    media_dir)
      outdir="${path}/flac"
      ;;
    device)
      outdir="${PWD}/bluray-rip"
      ;;
    *)
      outdir="${PWD}/bluray-rip"
      ;;
  esac

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    log_progress "would extract Blu-ray audio: $path -> $outdir/ (kind=$kind)"
    case "$kind" in
      media_file|media_dir) _bluray_dry_run_media "$path" "$kind" "$outdir" ;;
      *)
        if ! bluray_makemkv_bin >/dev/null; then
          log_err "would fail: MakeMKV is required to resolve authored Blu-ray titles"
          return 1
        fi
        log_info "  -> authored MakeMKV titles, then one FLAC per audio stream"
        ;;
    esac
    return
  fi

  mkdir -p -- "$outdir" || return 1
  tmpdir=$(make_workdir "$outdir")
  work="${tmpdir}/media"
  mkdir -p -- "$work"
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "bluray extract: $path (kind=$kind)"

  if ! bluray_decrypt_or_copy "$path" "$work" >"${tmpdir}/media.list"; then
    log_fail "$path" "decrypt/passthrough failed"
    cleanup
    return 1
  fi
  au_mapfile0 media "${tmpdir}/media.list"
  if ((${#media[@]} == 0)); then
    log_fail "$path" "no readable media after resolve"
    cleanup
    return 1
  fi

  case "$kind" in
    media_dir) source_root=$path ;;
    media_file) source_root=$(dirname -- "$path") ;;
    *) source_root=$work ;;
  esac
  for f in "${media[@]}"; do
    [[ -n "$f" ]] || continue
    if ! _extract_media_streams "$f" "$outdir" "$tmpdir" "$source_root"; then
      fail=1
    fi
  done

  cleanup
  ((fail == 0))
}
