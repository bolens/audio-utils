#!/usr/bin/env bash
# Shared helpers for the audio-utils MCP stdio server (dep-free).
# Sourced by mcp/server.sh and unit tests — no side effects on source.

# shellcheck shell=bash

shopt -s extglob

MCP_OUTPUT_CAP=65536
MCP_PROTOCOL_VERSION=2024-11-05

# --- repo / version -----------------------------------------------------------

mcp_repo_root() {
  local root
  root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
  [[ -f "$root/lib/plugin_init.sh" ]] || {
    echo "audio-utils-mcp: cannot find repo root (lib/plugin_init.sh)" >&2
    return 1
  }
  printf '%s' "$root"
}

mcp_version() {
  local root ver
  root=$(mcp_repo_root) || return 1
  ver=$(tr -d '[:space:]' <"$root/VERSION" 2>/dev/null || true)
  printf '%s' "${ver:-0.0.0}"
}

# --- JSON encode --------------------------------------------------------------

mcp_json_escape() {
  # Escape a string for inclusion inside JSON double quotes.
  local s=$1 out='' c i
  local -i n=${#s}
  for ((i = 0; i < n; i++)); do
    c=${s:i:1}
    case "$c" in
      \\) out+="\\\\" ;;
      \") out+="\\\"" ;;
      $'\n') out+='\n' ;;
      $'\r') out+='\r' ;;
      $'\t') out+='\t' ;;
      $'\b') out+='\b' ;;
      $'\f') out+='\f' ;;
      *)
        # Control chars U+0000–U+001F → \u00XX
        if [[ $(printf '%d' "'$c") -lt 32 ]]; then
          printf -v out '%s\\u%04x' "$out" "$(printf '%d' "'$c")"
        else
          out+=$c
        fi
        ;;
    esac
  done
  printf '%s' "$out"
}

mcp_json_string() {
  printf '"%s"' "$(mcp_json_escape "$1")"
}

# --- JSON decode (constrained) ------------------------------------------------
# Extractors operate on a single JSON object/array string. They find the first
# `"key":` occurrence and parse a string, number, bool, null, or string-array.

mcp_json_skip_ws() {
  # stdin → stdout with leading whitespace stripped (one line / blob)
  local s
  s=$(cat)
  s=${s##+([[:space:]])}
  printf '%s' "$s"
}

# Find value text after `"key":` in $1 (haystack). Writes value start offset to
# nameref $3 via remaining suffix in stdout starting at the value.
mcp_json_after_key() {
  local haystack=$1 key=$2
  local pat="\"${key}\"[[:space:]]*:[[:space:]]*"
  if [[ "$haystack" =~ $pat ]]; then
    local matched=${BASH_REMATCH[0]}
    local idx=${haystack%%"$matched"*}
    local start=$((${#idx} + ${#matched}))
    printf '%s' "${haystack:start}"
    return 0
  fi
  return 1
}

mcp_json_parse_string() {
  # $1 = text starting at opening quote; print unescaped string to stdout.
  local s=$1
  [[ "${s:0:1}" == '"' ]] || return 1
  s=${s:1}
  local out='' c
  local -i i=0 n=${#s}
  while ((i < n)); do
    c=${s:i:1}
    if [[ "$c" == '"' ]]; then
      printf '%s' "$out"
      return 0
    fi
    if [[ "$c" == "\\" ]]; then
      ((i++)) || true
      ((i < n)) || return 1
      c=${s:i:1}
      case "$c" in
        n) out+=$'\n' ;;
        r) out+=$'\r' ;;
        t) out+=$'\t' ;;
        b) out+=$'\b' ;;
        f) out+=$'\f' ;;
        u)
          # \uXXXX — take next 4 hex digits literally as codepoint if ASCII
          local hex=${s:i+1:4}
          if [[ "$hex" =~ ^[0-9a-fA-F]{4}$ ]]; then
            local code=$((16#$hex))
            if ((code < 128)); then
              printf -v c '%b' "\\x$(printf '%02x' "$code")"
              out+=$c
            else
              out+="?"
            fi
            ((i += 4)) || true
          else
            out+='u'
          fi
          ;;
        *) out+=$c ;;
      esac
    else
      out+=$c
    fi
    ((i++)) || true
  done
  return 1
}

mcp_json_get_raw() {
  # Usage: mcp_json_get_raw HAYSTACK KEY → prints raw value token start… (caller parses)
  mcp_json_after_key "$1" "$2"
}

mcp_json_get_string() {
  local rest
  rest=$(mcp_json_after_key "$1" "$2") || return 1
  rest=${rest##+([[:space:]])}
  [[ "${rest:0:1}" == '"' ]] || return 1
  mcp_json_parse_string "$rest"
}

mcp_json_get_bool() {
  local rest
  rest=$(mcp_json_after_key "$1" "$2") || return 1
  rest=${rest##+([[:space:]])}
  case "$rest" in
    true*) printf 'true'; return 0 ;;
    false*) printf 'false'; return 0 ;;
  esac
  return 1
}

mcp_json_get_number() {
  local rest
  rest=$(mcp_json_after_key "$1" "$2") || return 1
  rest=${rest##+([[:space:]])}
  if [[ "$rest" =~ ^(-?[0-9]+(\.[0-9]+)?) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

mcp_json_get_null_or_missing() {
  # Returns 0 if key missing or null; 1 if present with non-null value.
  local rest
  rest=$(mcp_json_after_key "$1" "$2") || return 0
  rest=${rest##+([[:space:]])}
  [[ "$rest" == null* ]] && return 0
  return 1
}

mcp_json_get_string_array() {
  # Print one string element per line. Empty array → no lines, exit 0.
  local rest elem
  rest=$(mcp_json_after_key "$1" "$2") || return 1
  rest=${rest##+([[:space:]])}
  [[ "${rest:0:1}" == '[' ]] || return 1
  rest=${rest:1}
  while true; do
    rest=${rest##+([[:space:]])}
    [[ "${rest:0:1}" == ']' ]] && return 0
    if [[ "${rest:0:1}" == ',' ]]; then
      rest=${rest:1}
      continue
    fi
    [[ "${rest:0:1}" == '"' ]] || return 1
    elem=$(mcp_json_parse_string "$rest") || return 1
    printf '%s\n' "$elem"
    # Advance past the string literal in rest
    local esc=0
    local -i i=1 n=${#rest}
    while ((i < n)); do
      local c=${rest:i:1}
      if ((esc)); then
        esc=0
        ((i++)) || true
        continue
      fi
      if [[ "$c" == "\\" ]]; then
        esc=1
        ((i++)) || true
        continue
      fi
      if [[ "$c" == '"' ]]; then
        ((i++)) || true
        break
      fi
      ((i++)) || true
    done
    rest=${rest:i}
  done
}

mcp_json_extract_object() {
  # Given text starting at `{`, print the balanced object (including braces).
  local s=$1
  [[ "${s:0:1}" == '{' ]] || return 1
  local -i depth=0 i=0 n=${#s} in_str=0 esc=0
  local c
  for ((i = 0; i < n; i++)); do
    c=${s:i:1}
    if ((in_str)); then
      if ((esc)); then
        esc=0
        continue
      fi
      case "$c" in
        \\) esc=1 ;;
        \") in_str=0 ;;
      esac
      continue
    fi
    case "$c" in
      \") in_str=1 ;;
      \{) ((depth++)) || true ;;
      \})
        ((depth--)) || true
        if ((depth == 0)); then
          printf '%s' "${s:0:i+1}"
          return 0
        fi
        ;;
    esac
  done
  return 1
}

mcp_json_get_object() {
  local rest
  rest=$(mcp_json_after_key "$1" "$2") || return 1
  rest=${rest##+([[:space:]])}
  mcp_json_extract_object "$rest"
}

# --- framing ------------------------------------------------------------------

mcp_write_message() {
  # Write one Content-Length framed JSON message to stdout.
  local body=$1
  local -i len
  len=$(printf '%s' "$body" | wc -c)
  printf 'Content-Length: %d\r\n\r\n%s' "$len" "$body"
}

mcp_read_message() {
  # Read one framed message from stdin into nameref variable $1.
  # Returns 1 on EOF before a full message.
  local -n _mcp_out=$1
  local line header_done=0 clen=0
  local -A headers=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Strip CR
    line=${line%$'\r'}
    if [[ -z "$line" ]]; then
      header_done=1
      break
    fi
    local key=${line%%:*}
    local val=${line#*:}
    val=${val##+([[:space:]])}
    key=$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')
    headers[$key]=$val
  done

  ((header_done)) || return 1
  clen=${headers[content-length]:-0}
  [[ "$clen" =~ ^[0-9]+$ ]] || return 1
  ((clen > 0)) || {
    _mcp_out=
    return 0
  }

  # Read exactly clen bytes
  local body
  body=$(head -c "$clen" 2>/dev/null || dd bs="$clen" count=1 2>/dev/null) || return 1
  # head -c may return short; ensure length
  local -i got
  got=$(printf '%s' "$body" | wc -c)
  if ((got < clen)); then
    local more
    more=$(dd bs=1 count=$((clen - got)) 2>/dev/null) || true
    body+=$more
  fi
  _mcp_out=$body
  return 0
}

# --- discovery ----------------------------------------------------------------

# Parallel arrays filled by mcp_discover:
#   MCP_TOOL_NAMES[i]   — CLI name (wav-to-flac)
#   MCP_TOOL_MCP[i]     — MCP tool id (wav_to_flac)
#   MCP_TOOL_KIND[i]    — conversion|util
#   MCP_TOOL_CATEGORY[i]— category or empty
#   MCP_TOOL_PATH[i]    — absolute entry script
#   MCP_TOOL_SUMMARY[i] — one-line summary

declare -ga MCP_TOOL_NAMES=()
declare -ga MCP_TOOL_MCP=()
declare -ga MCP_TOOL_KIND=()
declare -ga MCP_TOOL_CATEGORY=()
declare -ga MCP_TOOL_PATH=()
declare -ga MCP_TOOL_SUMMARY=()

mcp_cli_to_mcp_name() {
  printf '%s' "${1//-/_}"
}

mcp_mcp_to_cli_name() {
  # Prefer exact catalog match; else underscores → hyphens.
  local mcp=$1 i
  for i in "${!MCP_TOOL_MCP[@]}"; do
    if [[ "${MCP_TOOL_MCP[i]}" == "$mcp" ]]; then
      printf '%s' "${MCP_TOOL_NAMES[i]}"
      return 0
    fi
  done
  printf '%s' "${mcp//_/-}"
}

mcp_tool_summary() {
  # First non-shebang `#` comment line from entry script.
  local script=$1 line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == '#!'* ]] && continue
    [[ -z "$line" ]] && continue
    if [[ "$line" == '#'* ]]; then
      line=${line#\#}
      line=${line# }
      printf '%s' "$line"
      return 0
    fi
    break
  done <"$script"
  printf 'audio-utils tool'
}

mcp_discover() {
  local root=$1
  MCP_TOOL_NAMES=()
  MCP_TOOL_MCP=()
  MCP_TOOL_KIND=()
  MCP_TOOL_CATEGORY=()
  MCP_TOOL_PATH=()
  MCP_TOOL_SUMMARY=()

  local dir name script kind category summary
  # conversion/<name>/
  for dir in "$root"/conversion/*/ "$root"/conversion/*/*/; do
    [[ -d "$dir" ]] || continue
    [[ -f "${dir}Makefile" ]] || continue
    name=$(basename "${dir%/}")
    script="${dir}${name}.sh"
    [[ -f "$script" ]] || continue
    # Skip accidental nested non-tool dirs under conversion (none expected)
    kind=conversion
    category=
    # If deeper than conversion/name, treat as nested (rare)
    local rel=${dir#"$root"/conversion/}
    rel=${rel%/}
    if [[ "$rel" == */* ]]; then
      continue
    fi
    summary=$(mcp_tool_summary "$script")
    MCP_TOOL_NAMES+=("$name")
    MCP_TOOL_MCP+=("$(mcp_cli_to_mcp_name "$name")")
    MCP_TOOL_KIND+=("$kind")
    MCP_TOOL_CATEGORY+=("$category")
    MCP_TOOL_PATH+=("$script")
    MCP_TOOL_SUMMARY+=("$summary")
  done

  # util/<category>/<name>/
  for dir in "$root"/util/*/*/; do
    [[ -d "$dir" ]] || continue
    [[ -f "${dir}Makefile" ]] || continue
    name=$(basename "${dir%/}")
    script="${dir}${name}.sh"
    [[ -f "$script" ]] || continue
    category=$(basename "$(dirname "${dir%/}")")
    kind=util
    summary=$(mcp_tool_summary "$script")
    MCP_TOOL_NAMES+=("$name")
    MCP_TOOL_MCP+=("$(mcp_cli_to_mcp_name "$name")")
    MCP_TOOL_KIND+=("$kind")
    MCP_TOOL_CATEGORY+=("$category")
    MCP_TOOL_PATH+=("$script")
    MCP_TOOL_SUMMARY+=("$summary")
  done
}

mcp_resolve_index() {
  # Resolve CLI or MCP name → index into MCP_TOOL_* arrays.
  local want=$1 i
  for i in "${!MCP_TOOL_NAMES[@]}"; do
    if [[ "${MCP_TOOL_NAMES[i]}" == "$want" || "${MCP_TOOL_MCP[i]}" == "$want" ]]; then
      printf '%s' "$i"
      return 0
    fi
  done
  return 1
}

mcp_resolve_script() {
  local idx
  idx=$(mcp_resolve_index "$1") || return 1
  printf '%s' "${MCP_TOOL_PATH[idx]}"
}

# --- safety / run -------------------------------------------------------------

mcp_args_are_destructive() {
  local a
  for a in "$@"; do
    case "$a" in
      -d | -D | --apply) return 0 ;;
    esac
  done
  return 1
}

mcp_check_run_safety() {
  # Args: cli_name allow_destructive allow_network -- [cli args...]
  local cli_name=$1 allow_destructive=$2 allow_network=$3
  shift 3
  [[ "${1:-}" == -- ]] && shift

  if [[ "$cli_name" == tags-lookup && "$allow_network" != true && "$allow_network" != 1 ]]; then
    echo "tags-lookup requires allow_network=true (opt-in network boundary)" >&2
    return 2
  fi

  if mcp_args_are_destructive "$@" && [[ "$allow_destructive" != true && "$allow_destructive" != 1 ]]; then
    echo "destructive flags (-d/-D/--apply) require allow_destructive=true" >&2
    return 2
  fi
  return 0
}

mcp_run_cli() {
  # Run a tool entry script. Sets globals:
  #   MCP_LAST_EXIT MCP_LAST_STDOUT MCP_LAST_STDERR MCP_LAST_TRUNCATED
  local script=$1
  shift
  local out_f err_f rc=0
  out_f=$(mktemp) || return 1
  err_f=$(mktemp) || {
    rm -f "$out_f"
    return 1
  }

  set +e
  "$script" "$@" >"$out_f" 2>"$err_f"
  rc=$?
  set -e

  MCP_LAST_EXIT=$rc
  MCP_LAST_TRUNCATED=0
  local raw_out raw_err
  raw_out=$(cat "$out_f" || true)
  raw_err=$(cat "$err_f" || true)
  rm -f "$out_f" "$err_f"

  local -i olen elen
  olen=$(printf '%s' "$raw_out" | wc -c)
  elen=$(printf '%s' "$raw_err" | wc -c)
  if ((olen > MCP_OUTPUT_CAP)); then
    MCP_LAST_STDOUT=$(printf '%s' "$raw_out" | head -c "$MCP_OUTPUT_CAP")
    MCP_LAST_TRUNCATED=1
  else
    MCP_LAST_STDOUT=$raw_out
  fi
  if ((elen > MCP_OUTPUT_CAP)); then
    MCP_LAST_STDERR=$(printf '%s' "$raw_err" | head -c "$MCP_OUTPUT_CAP")
    MCP_LAST_TRUNCATED=1
  else
    MCP_LAST_STDERR=$raw_err
  fi
  return 0
}

mcp_format_run_result() {
  local text
  text="exit_code=${MCP_LAST_EXIT}"
  if ((MCP_LAST_TRUNCATED)); then
    text+=$'\n'"note: output truncated to ${MCP_OUTPUT_CAP} bytes"
  fi
  if [[ -n "${MCP_LAST_STDOUT:-}" ]]; then
    text+=$'\n'"--- stdout ---"$'\n'"$MCP_LAST_STDOUT"
  fi
  if [[ -n "${MCP_LAST_STDERR:-}" ]]; then
    text+=$'\n'"--- stderr ---"$'\n'"$MCP_LAST_STDERR"
  fi
  printf '%s' "$text"
}

# --- shared input schema JSON fragment ----------------------------------------

mcp_shared_props_json() {
  # Optional: include_name=1 adds name property
  local include_name=${1:-0}
  local props=''
  if [[ "$include_name" == 1 ]]; then
    props+='"name":{"type":"string","description":"CLI tool name (e.g. flac-verify, wav-to-flac)"},'
  fi
  props+='"paths":{"type":"array","items":{"type":"string"},"minItems":1,"description":"Directories or files to process (required; never empty)"},'
  props+='"args":{"type":"array","items":{"type":"string"},"description":"Extra CLI flags"},'
  props+='"jobs":{"type":"integer","default":1,"description":"Parallel jobs (-j N); default 1"},'
  props+='"dry_run":{"type":"boolean","default":false,"description":"Pass -n (dry run)"},'
  props+='"allow_destructive":{"type":"boolean","default":false,"description":"Allow -d/-D/--apply"},'
  props+='"allow_network":{"type":"boolean","default":false,"description":"Allow tags-lookup network"},'
  props+='"quiet":{"type":"boolean","default":true,"description":"Pass -q (default true)"}'
  printf '%s' "$props"
}

mcp_tool_schema_json() {
  local include_name=${1:-0}
  local required
  if [[ "$include_name" == 1 ]]; then
    required='["name","paths"]'
  else
    required='["paths"]'
  fi
  printf '{"type":"object","properties":{%s},"required":%s}' \
    "$(mcp_shared_props_json "$include_name")" "$required"
}

# --- build tools/list ---------------------------------------------------------

mcp_tools_list_json() {
  local parts=() i desc mcp_name
  # Meta tools
  parts+=("$(printf '{"name":"list_catalog","description":%s,"inputSchema":{"type":"object","properties":{}}}' \
    "$(mcp_json_string 'List all audio-utils conversion and util CLIs with kind, category, path, and summary.')")")
  parts+=("$(printf '{"name":"tool_help","description":%s,"inputSchema":{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}}' \
    "$(mcp_json_string 'Show -h usage for a named audio-utils CLI tool.')")")
  parts+=("$(printf '{"name":"run_tool","description":%s,"inputSchema":%s}' \
    "$(mcp_json_string 'Run any audio-utils CLI by name with path-scoped args and safety gates.')" \
    "$(mcp_tool_schema_json 1)")")

  for i in "${!MCP_TOOL_NAMES[@]}"; do
    mcp_name=${MCP_TOOL_MCP[i]}
    if [[ -n "${MCP_TOOL_CATEGORY[i]}" ]]; then
      desc="${MCP_TOOL_SUMMARY[i]} [${MCP_TOOL_KIND[i]}/${MCP_TOOL_CATEGORY[i]}: ${MCP_TOOL_NAMES[i]}]"
    else
      desc="${MCP_TOOL_SUMMARY[i]} [${MCP_TOOL_KIND[i]}: ${MCP_TOOL_NAMES[i]}]"
    fi
    parts+=("$(printf '{"name":%s,"description":%s,"inputSchema":%s}' \
      "$(mcp_json_string "$mcp_name")" \
      "$(mcp_json_string "$desc")" \
      "$(mcp_tool_schema_json 0)")")
  done

  local IFS=,
  printf '{"tools":[%s]}' "${parts[*]}"
}

mcp_catalog_text() {
  local i line
  for i in "${!MCP_TOOL_NAMES[@]}"; do
    line="${MCP_TOOL_NAMES[i]}	${MCP_TOOL_KIND[i]}	${MCP_TOOL_CATEGORY[i]:-}	${MCP_TOOL_PATH[i]}	${MCP_TOOL_SUMMARY[i]}"
    printf '%s\n' "$line"
  done
}

# --- argument parsing from tools/call ----------------------------------------

mcp_parse_run_args_from_json() {
  # Parse arguments object into globals:
  #   MCP_ARG_NAME MCP_ARG_PATHS (array) MCP_ARG_ARGS (array)
  #   MCP_ARG_JOBS MCP_ARG_DRY_RUN MCP_ARG_ALLOW_DESTRUCTIVE
  #   MCP_ARG_ALLOW_NETWORK MCP_ARG_QUIET
  local args_json=$1
  MCP_ARG_NAME=
  MCP_ARG_PATHS=()
  MCP_ARG_ARGS=()
  MCP_ARG_JOBS=1
  MCP_ARG_DRY_RUN=false
  MCP_ARG_ALLOW_DESTRUCTIVE=false
  MCP_ARG_ALLOW_NETWORK=false
  MCP_ARG_QUIET=true

  local v
  if v=$(mcp_json_get_string "$args_json" name 2>/dev/null); then
    MCP_ARG_NAME=$v
  fi

  if mcp_json_after_key "$args_json" paths >/dev/null 2>&1; then
    while IFS= read -r v; do
      [[ -n "$v" ]] && MCP_ARG_PATHS+=("$v")
    done < <(mcp_json_get_string_array "$args_json" paths)
  fi

  if mcp_json_after_key "$args_json" args >/dev/null 2>&1; then
    while IFS= read -r v; do
      [[ -n "$v" ]] && MCP_ARG_ARGS+=("$v")
    done < <(mcp_json_get_string_array "$args_json" args || true)
  fi

  if v=$(mcp_json_get_number "$args_json" jobs 2>/dev/null); then
    MCP_ARG_JOBS=$v
  fi
  if v=$(mcp_json_get_bool "$args_json" dry_run 2>/dev/null); then
    MCP_ARG_DRY_RUN=$v
  fi
  if v=$(mcp_json_get_bool "$args_json" allow_destructive 2>/dev/null); then
    MCP_ARG_ALLOW_DESTRUCTIVE=$v
  fi
  if v=$(mcp_json_get_bool "$args_json" allow_network 2>/dev/null); then
    MCP_ARG_ALLOW_NETWORK=$v
  fi
  if v=$(mcp_json_get_bool "$args_json" quiet 2>/dev/null); then
    MCP_ARG_QUIET=$v
  fi
}

mcp_build_cli_argv() {
  # Build argv into MCP_CLI_ARGV array from MCP_ARG_* globals + cli_name.
  local cli_name=$1
  MCP_CLI_ARGV=()
  local a
  if [[ "$MCP_ARG_QUIET" == true || "$MCP_ARG_QUIET" == 1 ]]; then
    MCP_CLI_ARGV+=(-q)
  fi
  if [[ "$MCP_ARG_DRY_RUN" == true || "$MCP_ARG_DRY_RUN" == 1 ]]; then
    MCP_CLI_ARGV+=(-n)
  fi
  if [[ -n "$MCP_ARG_JOBS" ]]; then
    MCP_CLI_ARGV+=(-j "$MCP_ARG_JOBS")
  fi
  for a in "${MCP_ARG_ARGS[@]+"${MCP_ARG_ARGS[@]}"}"; do
    MCP_CLI_ARGV+=("$a")
  done
  for a in "${MCP_ARG_PATHS[@]+"${MCP_ARG_PATHS[@]}"}"; do
    MCP_CLI_ARGV+=("$a")
  done
  # silence unused
  : "$cli_name"
}

# --- response helpers ---------------------------------------------------------

mcp_result_text() {
  # Wrap text in MCP CallToolResult / tools/call result content.
  local text=$1
  printf '{"content":[{"type":"text","text":%s}]}' "$(mcp_json_string "$text")"
}

mcp_error_response() {
  local id_json=$1 code=$2 message=$3
  printf '{"jsonrpc":"2.0","id":%s,"error":{"code":%s,"message":%s}}' \
    "$id_json" "$code" "$(mcp_json_string "$message")"
}

mcp_ok_response() {
  local id_json=$1 result_json=$2
  printf '{"jsonrpc":"2.0","id":%s,"result":%s}' "$id_json" "$result_json"
}

mcp_id_json() {
  # Extract id from request as a JSON literal (number, string, or null).
  local req=$1 rest
  if ! rest=$(mcp_json_after_key "$req" id); then
    printf 'null'
    return 0
  fi
  rest=${rest##+([[:space:]])}
  case "$rest" in
    null*) printf 'null' ;;
    true* | false*) printf '%s' "${rest%%[,\}]*}" ;;
    \"*)
      local s
      s=$(mcp_json_parse_string "$rest") || {
        printf 'null'
        return 0
      }
      mcp_json_string "$s"
      ;;
    -* | [0-9]*)
      if [[ "$rest" =~ ^(-?[0-9]+(\.[0-9]+)?) ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
      else
        printf 'null'
      fi
      ;;
    *) printf 'null' ;;
  esac
}

# --- request handler ----------------------------------------------------------

mcp_handle_initialize() {
  local ver
  ver=$(mcp_version)
  printf '{"protocolVersion":%s,"capabilities":{"tools":{}},"serverInfo":{"name":"audio-utils","version":%s}}' \
    "$(mcp_json_string "$MCP_PROTOCOL_VERSION")" \
    "$(mcp_json_string "$ver")"
}

mcp_handle_tools_call() {
  local req=$1
  local params args_json tool_mcp cli_name script idx err

  params=$(mcp_json_get_object "$req" params) || {
    echo "missing params" >&2
    return 1
  }
  tool_mcp=$(mcp_json_get_string "$params" name) || {
    echo "missing tool name" >&2
    return 1
  }

  args_json='{}'
  if args_json=$(mcp_json_get_object "$params" arguments 2>/dev/null); then
    :
  else
    args_json='{}'
  fi

  case "$tool_mcp" in
    list_catalog)
      mcp_result_text "$(mcp_catalog_text)"
      return 0
      ;;
    tool_help)
      local help_name
      help_name=$(mcp_json_get_string "$args_json" name) || {
        echo "tool_help requires name" >&2
        return 1
      }
      script=$(mcp_resolve_script "$help_name") || {
        echo "unknown tool: $help_name" >&2
        return 1
      }
      mcp_run_cli "$script" -h
      mcp_result_text "$(mcp_format_run_result)"
      return 0
      ;;
    run_tool)
      mcp_parse_run_args_from_json "$args_json"
      cli_name=$MCP_ARG_NAME
      [[ -n "$cli_name" ]] || {
        echo "run_tool requires name" >&2
        return 1
      }
      ;;
    *)
      # Per-format tool
      mcp_parse_run_args_from_json "$args_json"
      cli_name=$(mcp_mcp_to_cli_name "$tool_mcp")
      ;;
  esac

  ((${#MCP_ARG_PATHS[@]} >= 1)) || {
    echo "paths required (at least one); refusing pathless AUDIO_UTILS_ROOTS run" >&2
    return 1
  }

  idx=$(mcp_resolve_index "$cli_name") || {
    echo "unknown tool: $cli_name" >&2
    return 1
  }
  script=${MCP_TOOL_PATH[idx]}
  cli_name=${MCP_TOOL_NAMES[idx]}

  err=$(mcp_check_run_safety "$cli_name" "$MCP_ARG_ALLOW_DESTRUCTIVE" "$MCP_ARG_ALLOW_NETWORK" -- \
    "${MCP_ARG_ARGS[@]+"${MCP_ARG_ARGS[@]}"}" 2>&1) || {
    echo "$err" >&2
    return 1
  }

  mcp_build_cli_argv "$cli_name"
  mcp_run_cli "$script" "${MCP_CLI_ARGV[@]}"
  mcp_result_text "$(mcp_format_run_result)"
}

mcp_dispatch() {
  # $1 = request JSON. Prints response JSON (or empty for notifications).
  local req=$1
  local method id_json result err_msg

  method=$(mcp_json_get_string "$req" method) || {
    id_json=$(mcp_id_json "$req")
    mcp_error_response "$id_json" -32600 "Invalid Request: missing method"
    return 0
  }
  id_json=$(mcp_id_json "$req")

  case "$method" in
    initialize)
      result=$(mcp_handle_initialize)
      mcp_ok_response "$id_json" "$result"
      ;;
    notifications/initialized | initialized)
      # Notification — no response
      return 0
      ;;
    ping)
      mcp_ok_response "$id_json" '{}'
      ;;
    tools/list)
      result=$(mcp_tools_list_json)
      mcp_ok_response "$id_json" "$result"
      ;;
    tools/call)
      if result=$(mcp_handle_tools_call "$req" 2>"${TMPDIR:-/tmp}/mcp-err.$$"); then
        mcp_ok_response "$id_json" "$result"
      else
        err_msg=$(cat "${TMPDIR:-/tmp}/mcp-err.$$" 2>/dev/null || echo "tools/call failed")
        rm -f "${TMPDIR:-/tmp}/mcp-err.$$"
        # Tool errors as MCP error, or as isError result — use error for safety rejects
        mcp_error_response "$id_json" -32000 "$err_msg"
      fi
      rm -f "${TMPDIR:-/tmp}/mcp-err.$$"
      ;;
    *)
      mcp_error_response "$id_json" -32601 "Method not found: $method"
      ;;
  esac
}
