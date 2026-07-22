#!/usr/bin/env bash
# Playlist parse / write / path / dedupe helpers (M3U, M3U8, PLS, XSPF).
#
# Internal entry stream (stdout/stdin): US-separated fields (ASCII 0x1f)
#   path<US>title<US>duration
# path is absolute when emitted by playlist_parse; title/duration may be empty.
# duration is seconds (integer) or empty / -1 for unknown.
# Tab is avoided so empty titles do not collapse under bash IFS.

# Extensions treated as library audio when generating playlists.
playlist_audio_exts() {
  printf '%s\n' flac mp3 opus m4a ogg oga wma mpc spx aac wav aiff aif caf wv ape tak tta
}

# Detect format from extension (preferred) or light content sniff.
# Prints: m3u | pls | xspf
playlist_detect_format() {
  local f=$1 base
  base=$(basename -- "$f")
  case "${base,,}" in
    *.m3u|*.m3u8) printf 'm3u\n'; return 0 ;;
    *.pls) printf 'pls\n'; return 0 ;;
    *.xspf) printf 'xspf\n'; return 0 ;;
  esac
  if [[ -f "$f" ]]; then
    if head -n 5 -- "$f" 2>/dev/null | grep -qi '\[playlist\]'; then
      printf 'pls\n'; return 0
    fi
    if head -n 20 -- "$f" 2>/dev/null | grep -qi '<playlist'; then
      printf 'xspf\n'; return 0
    fi
    if head -n 1 -- "$f" 2>/dev/null | grep -qi '#extm3u'; then
      printf 'm3u\n'; return 0
    fi
  fi
  return 1
}

# Map format → preferred file extension (no leading dot).
playlist_ext_for_format() {
  case "$1" in
    m3u|m3u8) printf 'm3u\n' ;;
    pls) printf 'pls\n' ;;
    xspf) printf 'xspf\n' ;;
    *) return 1 ;;
  esac
}

# Canonical absolute path (best-effort).
playlist_canon_path() {
  local p=$1
  if [[ -e "$p" ]]; then
    au_abspath "$p"
    printf '\n'
  else
    # Non-existent: resolve parent if possible
    local d b
    d=$(cd -- "$(dirname -- "$p")" 2>/dev/null && pwd) || { printf '%s\n' "$p"; return 0; }
    b=$(basename -- "$p")
    printf '%s/%s\n' "$d" "$b"
  fi
}

# Resolve a playlist entry path against the playlist's directory → absolute.
playlist_resolve_entry() {
  local basedir=$1 entry=$2
  entry=${entry#$'\r'}
  entry=${entry%"${entry##*[![:space:]]}"}
  entry=${entry#"${entry%%[![:space:]]*}"}
  [[ -n "$entry" ]] || return 1
  case "$entry" in
    /*) playlist_canon_path "$entry" ;;
    *) playlist_canon_path "${basedir%/}/$entry" ;;
  esac
}

# Absolute path → relative to basedir (no leading ./). Fails if outside.
playlist_to_relative() {
  local basedir=$1 abspath=$2
  local abs_base abs_file
  abs_base=$(cd -- "$basedir" && pwd) || return 1
  abs_file=$(playlist_canon_path "$abspath")
  case "$abs_file" in
    "$abs_base"/*) printf '%s\n' "${abs_file#"$abs_base"/}" ;;
    "$abs_base") printf '.\n' ;;
    *) return 1 ;;
  esac
}

# Encode path as file:// URI (absolute).
playlist_file_uri() {
  local p=$1 abs
  abs=$(playlist_canon_path "$p")
  # Percent-encode spaces and a few reserved chars; leave path separators.
  local enc="" i c hex
  for ((i = 0; i < ${#abs}; i++)); do
    c=${abs:i:1}
    case "$c" in
      [A-Za-z0-9._~/-]) enc+="$c" ;;
      *)
        printf -v hex '%%%02X' "'$c"
        enc+="$hex"
        ;;
    esac
  done
  printf 'file://%s\n' "$enc"
}

# Decode file:// URI or plain path → filesystem path.
playlist_uri_to_path() {
  local u=$1 out="" i=0 c hex
  u=${u#$'\r'}
  u=${u%"${u##*[![:space:]]}"}
  u=${u#"${u%%[![:space:]]*}"}
  case "$u" in
    file://localhost/*) u=${u#file://localhost} ;;
    file:///*) u=${u#file://} ;;
    file://*) u=${u#file://} ;;
  esac
  while ((i < ${#u})); do
    c=${u:i:1}
    if [[ "$c" == '%' && $((i + 2)) -lt ${#u} ]]; then
      hex=${u:i+1:2}
      if [[ "$hex" =~ ^[0-9A-Fa-f]{2}$ ]]; then
        printf -v c '\\x%s' "$hex"
        printf -v c '%b' "$c"
        out+=$c
        i=$((i + 3))
        continue
      fi
    fi
    out+=$c
    ((i++)) || true
  done
  printf '%s\n' "$out"
}

# Sanitize title for entry stream (strip US/newlines).
_playlist_clean_field() {
  local s=$1
  s=${s//$'\x1f'/ }
  s=${s//$'\r'/}
  s=${s//$'\n'/ }
  s=${s//$'\t'/ }
  printf '%s' "$s"
}

# Emit one entry line (US-separated).
_playlist_emit() {
  local path=$1 title=${2:-} dur=${3:-}
  path=$(_playlist_clean_field "$path")
  title=$(_playlist_clean_field "$title")
  dur=$(_playlist_clean_field "$dur")
  [[ -n "$path" ]] || return 0
  printf '%s\x1f%s\x1f%s\n' "$path" "$title" "$dur"
}

# Parse M3U/M3U8 → TSV (absolute paths).
_playlist_parse_m3u() {
  local file=$1 basedir
  basedir=$(cd -- "$(dirname -- "$file")" && pwd) || return 1
  local line title="" dur="" path
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    case "$line" in
      ''|'#'*)
        if [[ "${line,,}" == \#extinf:* ]]; then
          local rest=${line#*:}
          dur=${rest%%,*}
          title=${rest#"$dur"}
          title=${title#,}
          [[ "$dur" =~ ^-?[0-9]+$ ]] || dur=""
        fi
        continue
        ;;
    esac
    path=$(playlist_resolve_entry "$basedir" "$line") || continue
    _playlist_emit "$path" "$title" "$dur"
    title=""; dur=""
  done <"$file"
}

# Parse PLS → TSV.
_playlist_parse_pls() {
  local file=$1 basedir
  basedir=$(cd -- "$(dirname -- "$file")" && pwd) || return 1
  local -A pls_files=() pls_titles=() pls_lengths=()
  local line key val n
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    [[ -z "$line" || "$line" == \[*\] ]] && continue
    key=${line%%=*}
    val=${line#*=}
    key=${key,,}
    case "$key" in
      file[0-9]*)
        n=${key#file}
        pls_files[$n]=$val
        ;;
      title[0-9]*)
        n=${key#title}
        pls_titles[$n]=$val
        ;;
      length[0-9]*)
        n=${key#length}
        pls_lengths[$n]=$val
        ;;
    esac
  done <"$file"
  local -a nums=()
  for n in "${!pls_files[@]}"; do
    nums+=("$n")
  done
  if ((${#nums[@]} == 0)); then
    return 0
  fi
  local sorted
  mapfile -t sorted < <(printf '%s\n' "${nums[@]}" | LC_ALL=C sort -n)
  local path
  for n in "${sorted[@]}"; do
    path=$(playlist_resolve_entry "$basedir" "${pls_files[$n]}") || continue
    _playlist_emit "$path" "${pls_titles[$n]:-}" "${pls_lengths[$n]:-}"
  done
}

# Parse XSPF (simple track/location/title extraction) → TSV.
_playlist_parse_xspf() {
  local file=$1 basedir
  basedir=$(cd -- "$(dirname -- "$file")" && pwd) || return 1
  # Flatten to one line per track-ish block via awk.
  local loc title path
  while IFS=$'\x1f' read -r loc title; do
    [[ -n "$loc" ]] || continue
    loc=$(playlist_uri_to_path "$loc")
    path=$(playlist_resolve_entry "$basedir" "$loc") || continue
    _playlist_emit "$path" "$title" ""
  done < <(
    awk '
      BEGIN { IGNORECASE=1; loc=""; title=""; in_track=0 }
      /<track[\s>]/ { in_track=1; loc=""; title=""; next }
      in_track && /<\/track>/ {
        if (loc != "") print loc "\x1f" title
        in_track=0; loc=""; title=""; next
      }
      in_track && /<location[^>]*>/ {
        line=$0
        sub(/.*<location[^>]*>/, "", line)
        sub(/<\/location>.*/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        loc=line
      }
      in_track && /<title[^>]*>/ {
        line=$0
        sub(/.*<title[^>]*>/, "", line)
        sub(/<\/title>.*/, "", line)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
        title=line
      }
    ' "$file"
  )
}

# Parse any supported playlist → TSV absolute entries.
playlist_parse() {
  local file=$1 fmt
  [[ -f "$file" ]] || return 1
  fmt=$(playlist_detect_format "$file") || return 1
  case "$fmt" in
    m3u) _playlist_parse_m3u "$file" ;;
    pls) _playlist_parse_pls "$file" ;;
    xspf) _playlist_parse_xspf "$file" ;;
    *) return 1 ;;
  esac
}

# Escape XML text.
_playlist_xml_escape() {
  local s=$1
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  s=${s//\"/&quot;}
  s=${s//\'/&apos;}
  printf '%s' "$s"
}

# Write playlist from TSV stdin.
# Args: FORMAT OUTFILE BASEDIR PATH_MODE
# PATH_MODE: relative | absolute
playlist_write() {
  local fmt=$1 out=$2 basedir=$3 mode=${4:-relative}
  case "$fmt" in
    m3u|m3u8) _playlist_write_m3u "$out" "$basedir" "$mode" ;;
    pls) _playlist_write_pls "$out" "$basedir" "$mode" ;;
    xspf) _playlist_write_xspf "$out" "$basedir" "$mode" ;;
    *) return 1 ;;
  esac
}

_playlist_entry_outpath() {
  local basedir=$1 abspath=$2 mode=$3
  local p
  if [[ "$mode" == absolute ]]; then
    playlist_canon_path "$abspath"
  else
    if p=$(playlist_to_relative "$basedir" "$abspath" 2>/dev/null); then
      printf '%s\n' "$p"
    else
      playlist_canon_path "$abspath"
    fi
  fi
}

_playlist_write_m3u() {
  local out=$1 basedir=$2 mode=$3
  local path title dur op tmp
  tmp=$(audio_utils_mktemp "pl.XXXXXX") || return 1
  {
    printf '#EXTM3U\n'
    while IFS=$'\x1f' read -r path title dur || [[ -n "${path:-}" ]]; do
      [[ -n "${path:-}" ]] || continue
      op=$(_playlist_entry_outpath "$basedir" "$path" "$mode")
      if [[ -n "$title" || -n "$dur" ]]; then
        [[ -n "$dur" && "$dur" =~ ^-?[0-9]+$ ]] || dur=-1
        printf '#EXTINF:%s,%s\n' "$dur" "$title"
      fi
      printf '%s\n' "$op"
    done
  } >"$tmp"
  mv -f -- "$tmp" "$out"
}

_playlist_write_pls() {
  local out=$1 basedir=$2 mode=$3
  local path title dur op tmp n=0
  local -a pl_paths=() pl_titles=() pl_durs=()
  while IFS=$'\x1f' read -r path title dur || [[ -n "${path:-}" ]]; do
    [[ -n "${path:-}" ]] || continue
    pl_paths+=("$path")
    pl_titles+=("$title")
    pl_durs+=("$dur")
  done
  tmp=$(audio_utils_mktemp "pl.XXXXXX") || return 1
  {
    printf '[playlist]\n'
    for ((n = 0; n < ${#pl_paths[@]}; n++)); do
      op=$(_playlist_entry_outpath "$basedir" "${pl_paths[n]}" "$mode")
      printf 'File%d=%s\n' "$((n + 1))" "$op"
      if [[ -n "${pl_titles[n]:-}" ]]; then
        printf 'Title%d=%s\n' "$((n + 1))" "${pl_titles[n]}"
      fi
      if [[ -n "${pl_durs[n]:-}" && "${pl_durs[n]}" =~ ^-?[0-9]+$ ]]; then
        printf 'Length%d=%s\n' "$((n + 1))" "${pl_durs[n]}"
      else
        printf 'Length%d=-1\n' "$((n + 1))"
      fi
    done
    printf 'NumberOfEntries=%d\n' "${#pl_paths[@]}"
    printf 'Version=2\n'
  } >"$tmp"
  mv -f -- "$tmp" "$out"
}

_playlist_write_xspf() {
  local out=$1 basedir=$2 mode=$3
  local path title dur op uri tmp
  tmp=$(audio_utils_mktemp "pl.XXXXXX") || return 1
  {
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
    printf '%s\n' '<playlist version="1" xmlns="http://xspf.org/ns/0/">'
    printf '%s\n' '  <trackList>'
    while IFS=$'\x1f' read -r path title dur || [[ -n "${path:-}" ]]; do
      [[ -n "${path:-}" ]] || continue
      if [[ "$mode" == absolute ]]; then
        uri=$(playlist_file_uri "$path")
      else
        op=$(_playlist_entry_outpath "$basedir" "$path" relative)
        # Relative locations as plain paths (common); absolute as file://
        if [[ "$op" == /* ]]; then
          uri=$(playlist_file_uri "$op")
        else
          uri=$op
        fi
      fi
      printf '    <track>\n'
      printf '      <location>%s</location>\n' "$(_playlist_xml_escape "$uri")"
      if [[ -n "$title" ]]; then
        printf '      <title>%s</title>\n' "$(_playlist_xml_escape "$title")"
      fi
      printf '    </track>\n'
    done
    printf '%s\n' '  </trackList>'
    printf '%s\n' '</playlist>'
  } >"$tmp"
  mv -f -- "$tmp" "$out"
}

# Normalize artist+title for soft dedupe.
playlist_normalize_title_key() {
  local artist=$1 title=$2
  local s
  s=$(printf '%s\t%s' "${artist,,}" "${title,,}")
  s=${s//[[:space:]]+/ }
  s=${s#"${s%%[![:space:]]*}"}
  s=${s%"${s##*[![:space:]]}"}
  printf '%s\n' "$s"
}

# Build dedupe key for one entry.
# MODE: path | title
# Uses optional tags from the audio file when mode=title.
playlist_entry_key() {
  local mode=$1 path=$2 title=${3:-}
  local artist t key
  case "$mode" in
    path)
      playlist_canon_path "$path"
      ;;
    title)
      artist=""
      t="$title"
      if [[ -f "$path" ]] && declare -F audio_meta_get >/dev/null 2>&1; then
        artist=$(audio_meta_get "$path" ARTIST 2>/dev/null || true)
        local tag_title
        tag_title=$(audio_meta_get "$path" TITLE 2>/dev/null || true)
        [[ -n "$tag_title" ]] && t=$tag_title
      fi
      if [[ -z "$t" ]]; then
        t=$(basename -- "$path")
        t=${t%.*}
      fi
      key=$(playlist_normalize_title_key "$artist" "$t")
      if [[ -z "$key" || "$key" == $'\t' ]]; then
        playlist_canon_path "$path"
      else
        printf '%s\n' "$key"
      fi
      ;;
    *)
      return 1
      ;;
  esac
}

# Dedupe TSV entries from stdin → stdout. Keep first occurrence.
# Args: MODE (path|title)
# Prints count of dropped entries to fd 3 if open, else ignores.
playlist_dedupe_entries() {
  local mode=${1:-path}
  local path title dur key
  local -A seen=()
  local dropped=0
  while IFS=$'\x1f' read -r path title dur || [[ -n "${path:-}" ]]; do
    [[ -n "${path:-}" ]] || continue
    key=$(playlist_entry_key "$mode" "$path" "$title") || key=$path
    if [[ -n "${seen[$key]:-}" ]]; then
      ((dropped++)) || true
      continue
    fi
    seen[$key]=1
    _playlist_emit "$path" "$title" "$dur"
  done
  if [[ -n "${PLAYLIST_DEDUPE_COUNT_FILE:-}" ]]; then
    printf '%s\n' "$dropped" >"$PLAYLIST_DEDUPE_COUNT_FILE"
  fi
}

# Count duplicate entries (path or title mode) without rewriting.
# Prints: total_entries duplicate_entries
playlist_count_dupes() {
  local mode=${1:-path}
  local path title dur key
  local -A seen=()
  local total=0 dupes=0
  while IFS=$'\x1f' read -r path title dur || [[ -n "${path:-}" ]]; do
    [[ -n "${path:-}" ]] || continue
    ((total++)) || true
    key=$(playlist_entry_key "$mode" "$path" "$title") || key=$path
    if [[ -n "${seen[$key]:-}" ]]; then
      ((dupes++)) || true
    else
      seen[$key]=1
    fi
  done
  printf '%d %d\n' "$total" "$dupes"
}

# List audio files in a directory (maxdepth 1), sorted.
playlist_list_audio_in_dir() {
  local dir=$1
  local -a exts find_expr
  local e first=1
  mapfile -t exts < <(playlist_audio_exts)
  find_expr=()
  for e in "${exts[@]}"; do
    if ((first)); then
      find_expr=( -iname "*.${e}" )
      first=0
    else
      find_expr+=( -o -iname "*.${e}" )
    fi
  done
  LC_ALL=C find -P "$dir" -maxdepth 1 -type f \( "${find_expr[@]}" \) | LC_ALL=C sort
}

# Build TSV entries from audio files in DIR (path identity dedupe).
# Titles/durations from tags when available.
playlist_entries_from_dir() {
  local dir=$1
  local f title artist dur key
  local -A seen=()
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    key=$(playlist_canon_path "$f")
    [[ -n "${seen[$key]:-}" ]] && continue
    seen[$key]=1
    title=""; artist=""; dur=""
    if declare -F audio_meta_get >/dev/null 2>&1; then
      title=$(audio_meta_get "$f" TITLE 2>/dev/null || true)
      artist=$(audio_meta_get "$f" ARTIST 2>/dev/null || true)
      if [[ -n "$artist" && -n "$title" ]]; then
        title="$artist - $title"
      elif [[ -n "$artist" && -z "$title" ]]; then
        title=$artist
      fi
    fi
    if command -v ffprobe >/dev/null 2>&1; then
      dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 -- "$f" 2>/dev/null | awk '{printf "%d", $1}')
    fi
    _playlist_emit "$key" "$title" "$dur"
  done < <(playlist_list_audio_in_dir "$dir")
}
