#!/usr/bin/env bash
# BDMV / device / decrypted media → per-stream FLAC

_bluray_stream_field() {
  local src="$1" idx="$2" field="$3"
  ffprobe -v error -select_streams "a:$idx" -show_entries "stream=$field" \
    -of default=noprint_wrappers=1:nokey=1 -- "$src" 2>/dev/null | head -n1
}

_bluray_stream_pcm_codec() {
  local src="$1" idx="$2" bits sample_fmt codec
  bits=$(_bluray_stream_field "$src" "$idx" bits_per_raw_sample)
  [[ "$bits" =~ ^[1-9][0-9]*$ ]] || bits=$(_bluray_stream_field "$src" "$idx" bits_per_sample)
  sample_fmt=$(_bluray_stream_field "$src" "$idx" sample_fmt)
  codec=$(_bluray_stream_field "$src" "$idx" codec_name)
  case "$codec" in
    pcm_f*)
      [[ "${AUDIO_UTILS_BD_ALLOW_FLOAT:-0}" -eq 1 ]] || return 2
      printf '%s\n' pcm_f32le
      return 0
      ;;
  esac
  if [[ "$bits" == 16 || "$sample_fmt" == s16 || "$sample_fmt" == s16p ]]; then
    printf '%s\n' pcm_s16le
  elif [[ "$bits" == 32 || "$codec" == pcm_s32* ]]; then
    printf '%s\n' pcm_s32le
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
      -of csv=p=0 -- "$f" 2>/dev/null | LC_ALL=C sort -u | grep -c . || true)
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

_bluray_source_size() {
  local path="$1" kind="$2"
  if [[ "$kind" == device ]]; then
    blockdev --getsize64 -- "$path" 2>/dev/null || return 1
  elif [[ -f "$path" ]]; then
    file_bytes "$path"
  else
    du -sb --apparent-size -- "$path" 2>/dev/null | awk '{print $1}'
  fi
}

_bluray_check_disk_preflight() {
  local path="$1" kind="$2" outdir="$3" bytes free need factor
  factor=${AU_DISK_FACTOR:-4}
  bytes=$(_bluray_source_size "$path" "$kind") || {
    log_info "warning: could not estimate Blu-ray source size; continuing"
    return 0
  }
  free=$(bytes_avail "$outdir")
  [[ "$bytes" =~ ^[0-9]+$ && "$free" =~ ^[0-9]+$ ]] || {
    log_info "warning: could not determine Blu-ray free-space requirement; continuing"
    return 0
  }
  need=$(awk -v b="$bytes" -v f="$factor" 'BEGIN { printf "%d", b*f }')
  if ((free < need)); then
    log_err "Error: insufficient space for Blu-ray conversion (need ~$need bytes, have $free)"
    return 1
  fi
  log_verbose "disk ok: source=$bytes free=$free need~=$need (x$factor)"
}

_bluray_stage_identity() {
  local path="$1" kind="$2" disc_id="${3:-}" material
  case "$kind" in
    device) material="device:$disc_id" ;;
    disc_image) material="iso:$(file_sha256 "$path")" ;;
    bdmv)
      material=$(find -P "$path" -type f \
        \( -iname 'index.bdmv' -o -iname 'MovieObject.bdmv' -o -path '*/PLAYLIST/*.mpls' \) \
        -print0 2>/dev/null | LC_ALL=C sort -z | xargs -0 -r sha256sum --)
      [[ -n "$material" ]] || material="bdmv-path:$(au_abspath "$path")"
      ;;
    *) return 1 ;;
  esac
  au_sha256_str "$material|title=${AUDIO_UTILS_BD_TITLE:-all}|min=${AUDIO_UTILS_BD_MIN_LENGTH:-0}"
}

_bluray_tag_stream_provenance() {
  local flac="$1" src="$2" idx="$3" source_audio_md5="$4"
  local field value codec profile source_class=unknown
  codec=$(_bluray_stream_field "$src" "$idx" codec_name)
  profile=$(_bluray_stream_field "$src" "$idx" profile)
  metaflac --remove-tag=SOURCE_CODEC --remove-tag=SOURCE_PROFILE \
    --remove-tag=SOURCE_LANGUAGE --remove-tag=SOURCE_TITLE \
    --remove-tag=SOURCE_CHANNEL_LAYOUT --remove-tag=SOURCE_SHA256 \
    --remove-tag=SOURCE_AUDIO_MD5 \
    --remove-tag=SOURCE_STREAM --remove-tag=SOURCE_CLASS \
    --remove-tag=SOURCE_CHANNELS --remove-tag=SOURCE_SAMPLE_RATE \
    --remove-tag=SOURCE_BITS_PER_SAMPLE --remove-tag=OUTPUT_BITS_PER_SAMPLE \
    --remove-tag=OBJECT_AUDIO_LOST --remove-tag=PRECISION_REDUCED \
    --remove-tag=LOSSY_SOURCE -- "$flac"
  metaflac --set-tag="SOURCE_AUDIO_MD5=$source_audio_md5" \
    --set-tag="SOURCE_STREAM=$idx" -- "$flac"
  [[ -n "$codec" ]] && metaflac --set-tag="SOURCE_CODEC=$codec" -- "$flac"
  [[ -n "$profile" ]] && metaflac --set-tag="SOURCE_PROFILE=$profile" -- "$flac"
  for field in language title; do
    value=$(ffprobe -v error -select_streams "a:$idx" \
      -show_entries "stream_tags=$field" -of default=nw=1:nk=1 -- "$src" 2>/dev/null | head -n1)
    [[ -n "$value" ]] && metaflac --set-tag="SOURCE_${field^^}=$value" -- "$flac"
  done
  value=$(_bluray_stream_field "$src" "$idx" channel_layout)
  [[ -n "$value" ]] && metaflac --set-tag="SOURCE_CHANNEL_LAYOUT=$value" -- "$flac"
  for field in channels sample_rate bits_per_raw_sample; do
    value=$(_bluray_stream_field "$src" "$idx" "$field")
    [[ -n "$value" && "$value" != N/A && "$value" != 0 ]] || continue
    case "$field" in
      channels) field=SOURCE_CHANNELS ;;
      sample_rate) field=SOURCE_SAMPLE_RATE ;;
      bits_per_raw_sample) field=SOURCE_BITS_PER_SAMPLE ;;
    esac
    metaflac --set-tag="$field=$value" -- "$flac"
  done
  metaflac --set-tag="OUTPUT_BITS_PER_SAMPLE=$(metaflac --show-bps "$flac")" -- "$flac"
  case "$codec" in
    pcm_*|flac|truehd|mlp) source_class=lossless ;;
    aac|ac3|eac3|mp2|mp3|vorbis|opus) source_class=lossy ;;
    dts)
      if [[ "${profile,,}" == *"ma"* ]]; then source_class=lossless
      else source_class=lossy
      fi
      ;;
  esac
  if [[ "${profile,,}" == *atmos* || "${profile,,}" == *dts:x* ]]; then
    metaflac --set-tag=OBJECT_AUDIO_LOST=1 -- "$flac"
  fi
  metaflac --set-tag="SOURCE_CLASS=$source_class" -- "$flac"
  [[ "$codec" == pcm_f* ]] && metaflac --set-tag=PRECISION_REDUCED=1 -- "$flac"
  if [[ "$source_class" == lossy ]]; then
    metaflac --set-tag=LOSSY_SOURCE=1 -- "$flac"
    log_info "note: stream a:$idx uses lossy source codec $codec${profile:+ ($profile)}"
  fi
}

_bluray_verify_decode_format() {
  local src="$1" idx="$2" wav="$3" src_rate src_channels wav_rate wav_channels
  local duration_ts time_base numerator denominator wav_samples
  src_rate=$(_bluray_stream_field "$src" "$idx" sample_rate)
  src_channels=$(_bluray_stream_field "$src" "$idx" channels)
  wav_rate=$(audio_sample_rate "$wav")
  wav_channels=$(audio_channels "$wav")
  if [[ "$src_rate" =~ ^[0-9]+$ && "$wav_rate" != "$src_rate" ]]; then
    log_err "VERIFY FAIL (sample rate changed $src_rate -> $wav_rate): $src#a$idx"
    return 1
  fi
  if [[ "$src_channels" =~ ^[0-9]+$ && "$wav_channels" != "$src_channels" ]]; then
    log_err "VERIFY FAIL (channel count changed $src_channels -> $wav_channels): $src#a$idx"
    return 1
  fi
  duration_ts=$(_bluray_stream_field "$src" "$idx" duration_ts)
  time_base=$(_bluray_stream_field "$src" "$idx" time_base)
  numerator=${time_base%/*}
  denominator=${time_base#*/}
  if [[ "$duration_ts" =~ ^[0-9]+$ && "$numerator" == 1 && \
    "$denominator" == "$src_rate" ]]; then
    wav_samples=$(audio_samples "$wav")
    if [[ "$wav_samples" =~ ^[0-9]+$ && "$wav_samples" != "$duration_ts" ]]; then
      log_err "VERIFY FAIL (sample count changed $duration_ts -> $wav_samples): $src#a$idx"
      return 1
    fi
  fi
}

_bluray_preserve_original_stream() {
  local src="$1" idx="$2" flac_out="$3" dest tmp err source_codec dest_codec
  [[ "${AUDIO_UTILS_BD_PRESERVE_STREAMS:-0}" -eq 1 ]] || return 0
  dest="${flac_out}.source.mka"
  tmp="${dest}.tmp.$$"
  err="${dest}.err.$$"
  source_codec=$(_bluray_stream_field "$src" "$idx" codec_name)
  ffmpeg -v error -xerror -y -i "$src" -map "0:a:$idx" -map_metadata 0:s:a:"$idx" \
    -c:a copy -f matroska "$tmp" 2>"$err" || { rm -f -- "$tmp"; return 1; }
  dest_codec=$(audio_codec "$tmp")
  if [[ -z "$source_codec" || "$dest_codec" != "$source_codec" ]]; then
    rm -f -- "$tmp"
    return 1
  fi
  mv -f -- "$tmp" "$dest" || return 1
  rm -f -- "$err"
}

_bluray_chapter_frames() {
  awk -v s="$1" 'BEGIN {
    frames=int((s * 75) + 0.5); mm=int(frames/(75*60));
    ss=int(frames/75)%60; ff=frames%75;
    printf "%02d:%02d:%02d", mm, ss, ff
  }'
}

_bluray_export_chapters() {
  local src="$1" flac_out="$2" list ffmeta json cue line idx start end title safe_title first=1
  local cue_enabled=1
  list="${flac_out}.chapters"
  ffmeta="${flac_out}.ffmetadata"
  json="${flac_out}.chapters.json"
  cue="${flac_out}.cue"
  if ! chapters_list "$src" >"$list" || [[ ! -s "$list" ]]; then
    rm -f -- "$list"
    return 0
  fi
  chapters_write_ffmetadata "$ffmeta" <"$list" || return 1
  printf '[\n' >"$json"
  if [[ "$(basename -- "$flac_out")" == *$'\n'* ]]; then
    cue_enabled=0
    log_info "note: CUE omitted because its FILE name contains a newline: $flac_out"
  else
    printf 'REM Generated by bluray-to-flac\nFILE "%s" FLAC\n' "$(basename -- "$flac_out")" >"$cue"
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    IFS='|' read -r idx start end title <<<"$line"
    ((first)) || printf ',\n' >>"$json"
    first=0
    printf '  {"index":%s,"start":%s,"end":%s,"title":%s}' \
      "$idx" "$start" "${end:-null}" "$(json_str "$title")" >>"$json"
    if ((cue_enabled)); then
      safe_title=${title//\"/\'}
      printf '  TRACK %02d AUDIO\n    TITLE "%s"\n    INDEX 01 %s\n' \
        "$idx" "$safe_title" "$(_bluray_chapter_frames "$start")" >>"$cue"
    fi
  done <"$list"
  printf '\n]\n' >>"$json"
  rm -f -- "$list"
}

_bluray_split_chapters() {
  local src="$1" flac_out="$2" tmpdir="$3" outdir="$4" audit_src="$5"
  local source_title="$6" source_stream="$7" list line idx start end title safe dir
  local bps pcm wav dest tags ctmp verify_dir concat_list concat_wav parent_wav
  local child_samples total_samples=0 first_start="" last_end="" parent_samples rate expected
  local -a trim chapter_enc
  [[ "${AUDIO_UTILS_BD_SPLIT_CHAPTERS:-0}" -eq 1 ]] || return 0
  list="${tmpdir}/chapters.list"
  chapters_list "$src" >"$list" || return 1
  [[ -s "$list" ]] || return 0
  dir="${flac_out%.flac}.chapters"
  mkdir -p -- "$dir" || return 1
  bps=$(metaflac --show-bps "$flac_out")
  case "$bps" in
    16) pcm=pcm_s16le ;;
    24) pcm=pcm_s24le ;;
    32) pcm=pcm_s32le ;;
    *) return 1 ;;
  esac
  tags="${tmpdir}/chapter-tags.txt"
  verify_dir="${tmpdir}/chapter-verify"
  concat_list="$verify_dir/concat.txt"
  mkdir -p -- "$verify_dir"
  : >"$concat_list"
  metaflac --export-tags-to="$tags" -- "$flac_out" || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    IFS='|' read -r idx start end title <<<"$line"
    [[ -n "$first_start" ]] || first_start=$start
    last_end=$end
    safe=$(chapters_sanitize_filename "${title:-Chapter $idx}")
    dest=$(printf '%s/%02d - %s.flac' "$dir" "$idx" "$safe")
    ctmp="${tmpdir}/chapter-work-${idx}"
    mkdir -p -- "$ctmp"
    wav="${ctmp}/chapter.wav"
    trim=(-ss "$start")
    [[ -n "$end" ]] && trim+=(-to "$end")
    if ! ffmpeg -v error -xerror -y "${trim[@]}" \
      -i "$flac_out" -map 0:a:0 -c:a "$pcm" "$wav" 2>"${tmpdir}/chapter.err"; then
      return 1
    fi
    if ! encode_flac_verified "$wav" "$ctmp" "$flac_out#chapter$idx" \
      >"${tmpdir}/chapter.enc"; then
      return 1
    fi
    au_mapfile0 chapter_enc "${tmpdir}/chapter.enc"
    metaflac --import-tags-from="$tags" --remove-tag=TRACKNUMBER --remove-tag=TITLE \
      --set-tag="TRACKNUMBER=$idx" --set-tag="TITLE=$title" -- "${chapter_enc[0]}" || return 1
    flac -t --silent "${chapter_enc[0]}" || return 1
    mv -f -- "${chapter_enc[0]}" "$dest"
    ln -s -- "$(au_abspath "$dest")" "$verify_dir/$idx.flac" || return 1
    printf "file '%s.flac'\n" "$idx" >>"$concat_list"
    child_samples=$(audio_samples "$dest")
    [[ "$child_samples" =~ ^[0-9]+$ ]] || return 1
    total_samples=$((total_samples + child_samples))
    _bluray_archive_record "$outdir" "$audit_src" \
      "$source_title#chapter$idx" "$source_stream" "$dest" \
      "$(audio_md5 "$dest")" || return 1
    rm -rf -- "$ctmp"
    rm -f -- "${tmpdir}/chapter.enc"
  done <"$list"
  rate=$(audio_sample_rate "$flac_out")
  if [[ "$first_start" =~ ^[0-9]+([.][0-9]+)?$ && \
    "$last_end" =~ ^[0-9]+([.][0-9]+)?$ && "$rate" =~ ^[0-9]+$ ]]; then
    expected=$(awk -v a="$first_start" -v b="$last_end" -v r="$rate" \
      'BEGIN { printf "%d", ((b-a)*r)+0.5 }')
    [[ "$total_samples" == "$expected" ]] || {
      log_err "VERIFY FAIL (chapter samples $total_samples != covered parent $expected)"
      return 1
    }
    parent_samples=$(audio_samples "$flac_out")
    concat_wav="$verify_dir/chapters.wav"
    ffmpeg -v error -xerror -y -f concat -safe 0 -i "$concat_list" \
      -map 0:a:0 -c:a "$pcm" "$concat_wav" 2>"$verify_dir/concat.err" || return 1
    if awk -v a="$first_start" 'BEGIN { exit !(a == 0) }' && \
      [[ "$parent_samples" =~ ^[0-9]+$ && "$expected" == "$parent_samples" ]]; then
      parent_wav=$flac_out
    else
      parent_wav="$verify_dir/parent-region.wav"
      ffmpeg -v error -xerror -y -ss "$first_start" -to "$last_end" \
        -i "$flac_out" -map 0:a:0 -c:a "$pcm" "$parent_wav" \
        2>"$verify_dir/parent.err" || return 1
    fi
    [[ "$(audio_md5 "$concat_wav")" == "$(audio_md5 "$parent_wav")" ]] || {
      log_err "VERIFY FAIL (concatenated chapter audio differs from parent region)"
      return 1
    }
  fi
}

_bluray_archive_init() {
  local outdir="$1" input="$2" prov
  prov="$outdir/provenance"
  mkdir -p -- "$prov" || return 1
  chmod u+w -- "$prov" "$prov"/* "$outdir/SHA256SUMS" 2>/dev/null || true
  AUDIO_UTILS_BD_SESSION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  export AUDIO_UTILS_BD_SESSION_ID
  rm -f -- "$outdir/ARCHIVE_COMPLETE.json"
  AUDIO_UTILS_BD_SESSION_MANIFEST="$prov/.session-${AUDIO_UTILS_BD_SESSION_ID}.jsonl"
  AUDIO_UTILS_BD_SESSION_VERSIONS="$prov/.session-${AUDIO_UTILS_BD_SESSION_ID}.versions"
  export AUDIO_UTILS_BD_SESSION_MANIFEST AUDIO_UTILS_BD_SESSION_VERSIONS
  : >"$AUDIO_UTILS_BD_SESSION_MANIFEST"
  {
    printf '\n[session %s]\n' "$AUDIO_UTILS_BD_SESSION_ID"
    printf 'created=%s\n' "$(au_iso_timestamp)"
    printf 'input=%s\n' "$input"
    printf 'audio_utils=%s\n' "$(audio_utils_version)"
    ffmpeg -version 2>/dev/null | head -n1
    ffprobe -version 2>/dev/null | head -n1
    flac --version 2>/dev/null
    metaflac --version 2>/dev/null
    if bluray_makemkv_bin >/dev/null; then
      "$(bluray_makemkv_bin)" --version 2>/dev/null | head -n1 || true
    fi
  } >"$AUDIO_UTILS_BD_SESSION_VERSIONS"
}

_bluray_archive_record() {
  local outdir="$1" input="$2" title="$3" idx="$4" flac="$5" md5="$6"
  local sha samples rate channels bps rel
  sha=$(file_sha256 "$flac")
  samples=$(audio_samples "$flac")
  rate=$(audio_sample_rate "$flac")
  channels=$(audio_channels "$flac")
  bps=$(metaflac --show-bps "$flac")
  rel=${flac#"$outdir"/}
  append_locked "$AUDIO_UTILS_BD_SESSION_MANIFEST" \
    '{"timestamp":"%s","session":"%s","input":%s,"title":%s,"stream":%s,"flac":%s,"audio_md5":"%s","sha256":"%s","samples":%s,"sample_rate":%s,"channels":%s,"bits_per_sample":%s}\n' \
    "$(au_iso_timestamp)" "${AUDIO_UTILS_BD_SESSION_ID:-unknown}" \
    "$(json_str "$input")" "$(json_str "$title")" "$idx" \
    "$(json_str "$rel")" "$md5" "$sha" "${samples:-0}" "${rate:-0}" \
    "${channels:-0}" "${bps:-0}"
}

_bluray_archive_commit_metadata() {
  local outdir="$1" prov tmp
  prov="$outdir/provenance"
  (
    flock 9 || exit 1
    tmp="$prov/.archive-manifest.new"
    [[ -f "$prov/archive-manifest.jsonl" ]] && cp -f -- "$prov/archive-manifest.jsonl" "$tmp" || : >"$tmp"
    cat -- "$AUDIO_UTILS_BD_SESSION_MANIFEST" >>"$tmp"
    mv -f -- "$tmp" "$prov/archive-manifest.jsonl" || exit 1
    tmp="$prov/.tool-versions.new"
    [[ -f "$prov/tool-versions.txt" ]] && cp -f -- "$prov/tool-versions.txt" "$tmp" || : >"$tmp"
    cat -- "$AUDIO_UTILS_BD_SESSION_VERSIONS" >>"$tmp"
    mv -f -- "$tmp" "$prov/tool-versions.txt" || exit 1
  ) 9>"$prov/.archive.lock" || return 1
  rm -f -- "$AUDIO_UTILS_BD_SESSION_MANIFEST" "$AUDIO_UTILS_BD_SESSION_VERSIONS"
}

_bluray_archive_abort_metadata() {
  rm -f -- "${AUDIO_UTILS_BD_SESSION_MANIFEST:-}" "${AUDIO_UTILS_BD_SESSION_VERSIONS:-}"
}

_bluray_persist_transport_logs() {
  local media_work="$1" outdir="$2" f
  for f in .makemkv-info.txt makemkv.err makemkv-warnings.log; do
    [[ -f "$media_work/$f" ]] && cp -f -- "$media_work/$f" "$outdir/provenance/$f"
  done
  if [[ -f "$media_work/.makemkv-info.txt" ]]; then
    awk -F, '
      BEGIN { print "title\tduration\tbytes\tplaylist\tsegments\tfilename" }
      /^TINFO:/ {
        title=$1; sub(/^TINFO:/, "", title); value=$4; gsub(/^"|"$/, "", value)
        if ($2==9) duration[title]=value
        else if ($2==11) bytes[title]=value
        else if ($2==16) playlist[title]=value
        else if ($2==26) segments[title]=value
        else if ($2==27) filename[title]=value
        seen[title]=1
      }
      END { for (title in seen) print title "\t" duration[title] "\t" bytes[title] "\t" playlist[title] "\t" segments[title] "\t" filename[title] }
    ' "$media_work/.makemkv-info.txt" | LC_ALL=C sort -t$'\t' -k1,1n \
      >"$outdir/provenance/makemkv-titles.tsv"
  fi
  if [[ -f "$media_work/makemkv.err" ]]; then
    awk -F, '/^MSG:/ {
      code=$1; sub(/^MSG:/, "", code); flags=$2; text=$4; gsub(/^"|"$/, "", text)
      severity=(tolower(text) ~ /fatal|failed|corrupt|read error/) ? "warning" : "info"
      print severity "\t" code "\t" flags "\t" text
    }' "$media_work/makemkv.err" >"$outdir/provenance/makemkv-messages.tsv"
  fi
}

bluray_write_checksums() {
  local outdir="$1" tmp
  tmp="$outdir/.SHA256SUMS.tmp"
  (
    cd -- "$outdir"
    find -P . -type f ! -name SHA256SUMS ! -name '.SHA256SUMS.tmp' \
      \( -name '*.flac' -o -name '*.cue' -o -name '*.ffmetadata' \
      -o -name '*.chapters.json' -o -name '*.source.mka' \
      -o -path './provenance/*' \) -print0 \
      | LC_ALL=C sort -z | xargs -0 -r sha256sum --
  ) >"$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f -- "$tmp" "$outdir/SHA256SUMS"
  (cd -- "$outdir" && sha256sum -c --quiet SHA256SUMS)
}

_bluray_archive_finalize() {
  local outdir="$1" sum_sha pct key f
  local -a recovery_files=()
  _bluray_archive_commit_metadata "$outdir" || return 1
  bluray_write_checksums "$outdir" || return 1
  if [[ -n "${AUDIO_UTILS_BD_SIGN_KEY:-}" ]]; then
    key=$AUDIO_UTILS_BD_SIGN_KEY
    minisign -S -s "$key" -m "$outdir/SHA256SUMS" \
      -x "$outdir/SHA256SUMS.minisig" >/dev/null || return 1
  fi
  pct=${AUDIO_UTILS_BD_PAR2_PERCENT:-0}
  if ((pct > 0)); then
    while IFS= read -r -d '' f; do recovery_files+=("$f"); done < <(
      find -P "$outdir" -type f \( -name '*.flac' -o -name '*.source.mka' \
        -o -name '*.cue' -o -name '*.ffmetadata' -o -name '*.chapters.json' \
        -o -name 'SHA256SUMS' -o -name 'SHA256SUMS.minisig' \
        -o -path '*/provenance/*' \) -print0)
    find -P "$outdir" -maxdepth 1 -type f -name 'archive*.par2' -delete
    par2 create -q "-r$pct" "$outdir/archive" "${recovery_files[@]}" >/dev/null || return 1
  fi
  sync -f "$outdir" 2>/dev/null || sync
  sum_sha=$(file_sha256 "$outdir/SHA256SUMS")
  printf '{"status":"complete","session":"%s","completed":"%s","sha256sums":"%s"}\n' \
    "$AUDIO_UTILS_BD_SESSION_ID" "$(au_iso_timestamp)" "$sum_sha" \
    >"$outdir/ARCHIVE_COMPLETE.json"
  sync -f "$outdir/ARCHIVE_COMPLETE.json" 2>/dev/null || sync
  if [[ "${AUDIO_UTILS_BD_SEAL:-0}" -eq 1 ]]; then
    chmod a-w -- "$outdir/SHA256SUMS" "$outdir/ARCHIVE_COMPLETE.json" \
      "$outdir/provenance"/* 2>/dev/null || return 1
  fi
}

bluray_verify_archive() {
  local outdir="$1" recorded actual
  local -a mini_args
  [[ -d "$outdir" && -s "$outdir/SHA256SUMS" && -s "$outdir/ARCHIVE_COMPLETE.json" ]] || {
    log_err "Error: archive is incomplete or has no SHA256SUMS: $outdir"
    return 1
  }
  recorded=$(sed -n 's/.*"sha256sums":"\([0-9a-f]*\)".*/\1/p' "$outdir/ARCHIVE_COMPLETE.json")
  actual=$(file_sha256 "$outdir/SHA256SUMS")
  [[ -n "$recorded" && "$recorded" == "$actual" ]] || return 1
  (cd -- "$outdir" && sha256sum -c SHA256SUMS) || return 1
  if [[ -f "$outdir/SHA256SUMS.minisig" ]]; then
    command -v minisign >/dev/null 2>&1 || return 1
    mini_args=(-Vm "$outdir/SHA256SUMS" -x "$outdir/SHA256SUMS.minisig")
    [[ -n "${AUDIO_UTILS_BD_SIGN_PUBKEY:-}" ]] && mini_args+=(-P "$AUDIO_UTILS_BD_SIGN_PUBKEY")
    minisign "${mini_args[@]}" >/dev/null || return 1
  fi
}

bluray_audit_archive() {
  local outdir="$1" f decoded stored fail=0
  bluray_verify_archive "$outdir" || fail=1
  while IFS= read -r -d '' f; do
    flac -t --silent "$f" || { log_err "invalid FLAC: $f"; fail=1; }
    decoded=$(audio_md5 "$f")
    stored=$(metaflac --show-md5sum -- "$f" 2>/dev/null)
    [[ -n "$decoded" && "$decoded" == "$stored" ]] || {
      log_err "decoded audio MD5 differs from FLAC STREAMINFO: $f"
      fail=1
    }
  done < <(find -P "$outdir" -type f -name '*.flac' -print0)
  if [[ -f "$outdir/archive.par2" ]]; then
    command -v par2 >/dev/null 2>&1 && par2 verify "$outdir/archive.par2" >/dev/null || fail=1
  fi
  ((fail == 0))
}

_bluray_existing_matches_source() {
  local flac="$1" source_audio_md5="$2" idx="$3" tagged_md5 tagged_stream flac_md5
  [[ -f "$flac" ]] && flac_ok "$flac" || return 1
  tagged_md5=$(metaflac --show-tag=SOURCE_AUDIO_MD5 -- "$flac" 2>/dev/null)
  tagged_stream=$(metaflac --show-tag=SOURCE_STREAM -- "$flac" 2>/dev/null)
  flac_md5=$(audio_md5 "$flac")
  [[ "$tagged_md5" == "SOURCE_AUDIO_MD5=$source_audio_md5" && \
    "$tagged_stream" == "SOURCE_STREAM=$idx" && "$flac_md5" == "$source_audio_md5" ]]
}

_bluray_parse_duration_tag() {
  awk -F: 'NF == 3 {
    seconds=($1 * 3600) + ($2 * 60) + $3
    if (seconds >= 0) printf "%.9f\n", seconds
  }' <<<"$1"
}

_bluray_source_duration() {
  local src="$1" idx="$2" duration
  duration=$(_bluray_stream_field "$src" "$idx" duration)
  if [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s\n' "$duration"
    return 0
  fi
  duration=$(ffprobe -v error -select_streams "a:$idx" \
    -show_entries stream_tags=DURATION -of default=nw=1:nk=1 -- "$src" 2>/dev/null | head -n1)
  duration=$(_bluray_parse_duration_tag "$duration")
  if [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s\n' "$duration"
    return 0
  fi
  ffprobe -v error -show_entries format=duration \
    -of default=nw=1:nk=1 -- "$src" 2>/dev/null | head -n1
}

_bluray_verify_decode_length() {
  local src="$1" idx="$2" wav="$3" src_duration wav_duration
  src_duration=$(_bluray_source_duration "$src" "$idx")
  wav_duration=$(audio_duration_sec "$wav")
  if [[ ! "$src_duration" =~ ^[0-9]+([.][0-9]+)?$ || \
    ! "$wav_duration" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    log_note "note: stream a:$idx duration unavailable; relying on strict decoder errors"
    return 0
  fi
  if awk -v s="$src_duration" -v w="$wav_duration" \
    'BEGIN { tolerance=0.25; exit !((s-w) > tolerance) }'; then
    AUDIO_UTILS_LAST_ERR="source_duration=$src_duration decoded_duration=$wav_duration"
    export AUDIO_UTILS_LAST_ERR
    log_err "VERIFY FAIL (decoded audio shorter than source): $src#a$idx"
    return 1
  fi
}

_extract_media_streams() {
  local src="$1" outdir="$2" tmpdir="$3" source_root="$4" audit_src="$5"
  local base rel rel_dir n i wav flac_out pcm_codec source_audio_md5 title_note
  local encode_src floatdir
  local -a enc_out prep_out
  local fail=0

  base=$(basename -- "$src")
  rel=${src#"$source_root"/}
  if [[ "$rel" == "$src" ]]; then
    rel_dir=.
  else
    rel_dir=$(dirname -- "$rel")
  fi
  mkdir -p -- "$outdir/$rel_dir" || return 1
  title_note=${rel#./}
  n=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 -- "$src" 2>/dev/null | LC_ALL=C sort -u | grep -c . || true)
  n=${n:-0}
  ((n >= 1)) || {
    log_fail "$src" "no audio streams"
    return 1
  }
  for ((i = 0; i < n; i++)); do
    flac_out=$(_bluray_output_path "$src" "$outdir" "$source_root" "$i")
    wav="${tmpdir}/${base}.a${i}.wav"
    if ! pcm_codec=$(_bluray_stream_pcm_codec "$src" "$i"); then
      log_fail "$src" "float PCM requires --allow-float-reduction for a:$i"
      fail=1
      continue
    fi

    if ! ffmpeg -v error -xerror -err_detect explode -y -i "$src" \
      -map "0:a:${i}" -c:a "$pcm_codec" "$wav" 2>"${tmpdir}/ex.err"; then
      set_last_err_file "${tmpdir}/ex.err"
      log_fail "$src" "extract a:$i failed"
      fail=1
      continue
    fi
    if ! _bluray_verify_decode_format "$src" "$i" "$wav"; then
      log_fail "$src" "decoded format verification failed for a:$i"
      fail=1
      continue
    fi
    encode_src=$wav
    if [[ "$pcm_codec" == pcm_f32le ]]; then
      floatdir="${tmpdir}/float-${i}"
      mkdir -p -- "$floatdir"
      if ! prepare_float "$wav" "$floatdir" pcm_f32le >"${tmpdir}/float.path"; then
        log_fail "$src" "float precision reduction failed for a:$i"
        fail=1
        continue
      fi
      au_mapfile0 prep_out "${tmpdir}/float.path"
      encode_src=${prep_out[0]}
    fi
    source_audio_md5=$(audio_md5 "$encode_src")
    if [[ -z "$source_audio_md5" ]]; then
      log_fail "$src" "decoded audio MD5 failed for a:$i"
      fail=1
      continue
    fi
    if ! _bluray_verify_decode_length "$src" "$i" "$wav"; then
      log_fail "$src" "decode length verification failed for a:$i"
      fail=1
      continue
    fi
    if [[ -f "$flac_out" && "${OVERWRITE:-0}" -eq 0 ]]; then
      if _bluray_existing_matches_source "$flac_out" "$source_audio_md5" "$i"; then
        log_progress "skip (source-bound flac ok): $flac_out"
        log_success "$audit_src" "$flac_out" "$source_audio_md5" "$(file_sha256 "$flac_out")" \
          "skipped-existing-ok;title=$title_note;stream=$i"
        _bluray_export_chapters "$src" "$flac_out" || return 1
        _bluray_split_chapters "$src" "$flac_out" "$tmpdir" "$outdir" \
          "$audit_src" "$title_note" "$i" || return 1
        _bluray_preserve_original_stream "$src" "$i" "$flac_out" || return 1
        _bluray_archive_record "$outdir" "$audit_src" "$title_note" "$i" \
          "$flac_out" "$source_audio_md5" || return 1
        rm -f -- "$wav"
        continue
      fi
      log_fail "$src" "existing output does not match source audio; use -y: $flac_out"
      fail=1
      rm -f -- "$wav"
      continue
    fi
    if ! encode_flac_verified "$encode_src" "$tmpdir" "$src#a$i" >"${tmpdir}/enc.out"; then
      log_fail "$src" "encode a:$i failed"
      fail=1
      continue
    fi
    au_mapfile0 enc_out "${tmpdir}/enc.out"
    if ! _bluray_tag_stream_provenance "${enc_out[0]}" "$src" "$i" "$source_audio_md5"; then
      log_fail "$src" "tag stream a:$i failed"
      fail=1
      continue
    fi
    if ! flac -t --silent "${enc_out[0]}" 2>"${tmpdir}/final-test.err"; then
      set_last_err_file "${tmpdir}/final-test.err"
      log_fail "$src" "final tagged FLAC verification failed for a:$i"
      fail=1
      continue
    fi
    mv -f -- "${enc_out[0]}" "$flac_out"
    log_info "verified: $flac_out"
    log_success "$audit_src" "$flac_out" "${enc_out[2]}" "$(file_sha256 "$flac_out")" \
      "converted;title=$title_note;stream=$i"
    if ! _bluray_export_chapters "$src" "$flac_out"; then
      log_fail "$src" "chapter sidecar export failed for a:$i"
      fail=1
      continue
    fi
    if ! _bluray_split_chapters "$src" "$flac_out" "$tmpdir" "$outdir" \
      "$audit_src" "$title_note" "$i"; then
      log_fail "$src" "chapter splitting failed for a:$i"
      fail=1
      continue
    fi
    if ! _bluray_preserve_original_stream "$src" "$i" "$flac_out"; then
      log_fail "$src" "original stream preservation failed for a:$i"
      fail=1
      continue
    fi
    if ! _bluray_archive_record "$outdir" "$audit_src" "$title_note" "$i" \
      "$flac_out" "${enc_out[2]}"; then
      log_fail "$src" "archive manifest update failed for a:$i"
      fail=1
      continue
    fi
    rm -f -- "$wav" \
      "${tmpdir}/pass1.flac" "${tmpdir}/pass2.flac" "${tmpdir}/pass3.flac" \
      "${tmpdir}/roundtrip.flac" "${tmpdir}/decoded.wav" "${tmpdir}/enc.out" 2>/dev/null || true
  done
  return "$fail"
}

convert_one() {
  local path="$1"
  local outdir tmpdir work media_work media fail=0 kind disc_label source_root disc_id stage_key stage_id

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
    disc_image)
      disc_label=$(basename -- "$path")
      outdir="$(dirname -- "$path")/${disc_label%.*}.flac"
      ;;
    device)
      disc_id=$(bluray_device_id "$path") || {
        log_fail "$path" "cannot identify Blu-ray disc with MakeMKV"
        return 1
      }
      outdir="${PWD}/bluray-rip/${disc_id}"
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
  _bluray_check_disk_preflight "$path" "$kind" "$outdir" || return 1
  _bluray_archive_init "$outdir" "$path" || return 1
  tmpdir=$(make_workdir "$outdir")
  work="${tmpdir}/media"
  mkdir -p -- "$work"
  media_work=$work
  if [[ -n "${AUDIO_UTILS_BD_STAGE_DIR:-}" && \
    ( "$kind" == bdmv || "$kind" == device || "$kind" == disc_image ) ]]; then
    if [[ "$kind" == device ]]; then
      stage_id=$(_bluray_stage_identity "$path" "$kind" "$disc_id") || return 1
    else
      stage_id=$(_bluray_stage_identity "$path" "$kind") || return 1
    fi
    stage_key="source-${stage_id:0:16}"
    media_work="${AUDIO_UTILS_BD_STAGE_DIR}/${stage_key}"
    mkdir -p -- "$media_work" || return 1
    if [[ -f "$media_work/.source-id" && "$(<"$media_work/.source-id")" != "$stage_id" ]]; then
      log_fail "$path" "staging identity mismatch: $media_work"
      return 1
    fi
    printf '%s\n' "$stage_id" >"$media_work/.source-id"
    AUDIO_UTILS_BD_RESUME=1
    export AUDIO_UTILS_BD_RESUME
  fi
  cleanup() { unregister_tmpdir "$tmpdir"; rm -rf -- "$tmpdir" 2>/dev/null || true; }

  log_progress "bluray extract: $path (kind=$kind)"

  if ! bluray_decrypt_or_copy "$path" "$media_work" >"${tmpdir}/media.list"; then
    log_fail "$path" "decrypt/passthrough failed"
    _bluray_persist_transport_logs "$media_work" "$outdir"
    _bluray_archive_abort_metadata
    cleanup
    return 1
  fi
  au_mapfile0 media "${tmpdir}/media.list"
  if ((${#media[@]} == 0)); then
    log_fail "$path" "no readable media after resolve"
    _bluray_persist_transport_logs "$media_work" "$outdir"
    _bluray_archive_abort_metadata
    cleanup
    return 1
  fi

  case "$kind" in
    media_dir) source_root=$path ;;
    media_file) source_root=$(dirname -- "$path") ;;
    *) source_root=$media_work ;;
  esac
  for f in "${media[@]}"; do
    [[ -n "$f" ]] || continue
    if ! _extract_media_streams "$f" "$outdir" "$tmpdir" "$source_root" "$path"; then
      fail=1
    fi
  done

  _bluray_persist_transport_logs "$media_work" "$outdir"
  if ((fail == 0)); then
    _bluray_archive_finalize "$outdir" || fail=1
  else
    _bluray_archive_abort_metadata
  fi

  cleanup
  ((fail == 0))
}
