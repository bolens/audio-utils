#!/usr/bin/env bash
# flac-authenticity plugin — detect fake lossless / upsampled / padded FLACs.

AU_TOOL_NAME="${AU_TOOL_NAME:-flac-authenticity}"
AU_SOURCE_EXT=flac
AU_DEST_EXT=flac
AU_DISK_FACTOR=0
AU_WORKDIR_PREFIX=flacauth
AU_SUCCESS_COLUMNS='timestamp,flac,verdict,audio_md5,flac_sha256,codec,bytes,samples,notes'
AU_GETOPT_EXTRA="sp"
AU_CLEANUP_SKIP=1

_AU_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
while [[ ! -f "$_AU_ROOT/lib/plugin_init.sh" ]]; do
  # shellcheck disable=SC2317  # exit only reached when executed, not sourced
  [[ "$_AU_ROOT" != / ]] || { echo "audio-utils: shared lib/ not found" >&2; return 1 2>/dev/null || exit 2; }
  _AU_ROOT=$(dirname "$_AU_ROOT")
done
# shellcheck source=../../../../lib/plugin_init.sh
source "$_AU_ROOT/lib/plugin_init.sh"

AUTH_STRICT="${AUTH_STRICT:-0}"
AUTH_SPECTROGRAM="${AUTH_SPECTROGRAM:-0}"
AUTH_SPECTROGRAM_ALL="${AUTH_SPECTROGRAM_ALL:-0}"
# auto | sox | ffmpeg | both
AUTH_SPECTROGRAM_BACKEND="${AUTH_SPECTROGRAM_BACKEND:-auto}"
AUTH_HAVE_SOX="${AUTH_HAVE_SOX:-0}"
AUTH_HAVE_MEDIAINFO="${AUTH_HAVE_MEDIAINFO:-0}"

plugin_parse_opt() {
  case "$1" in
    s)
      AUTH_STRICT=1
      export AUTH_STRICT
      return 0
      ;;
    p)
      AUTH_SPECTROGRAM=1
      export AUTH_SPECTROGRAM
      return 0
      ;;
  esac
  return 1
}

plugin_consume_arg() {
  case "${1:-}" in
    --strict)
      AUTH_STRICT=1
      AU_CONSUMED=1
      export AU_CONSUMED AUTH_STRICT
      return 0
      ;;
    --spectrogram)
      AUTH_SPECTROGRAM=1
      AU_CONSUMED=1
      export AU_CONSUMED AUTH_SPECTROGRAM
      return 0
      ;;
    --spectrogram-all)
      AUTH_SPECTROGRAM=1
      AUTH_SPECTROGRAM_ALL=1
      AU_CONSUMED=1
      export AU_CONSUMED AUTH_SPECTROGRAM AUTH_SPECTROGRAM_ALL
      return 0
      ;;
    --spectrogram-backend=*)
      AUTH_SPECTROGRAM_BACKEND="${1#--spectrogram-backend=}"
      AU_CONSUMED=1
      export AU_CONSUMED AUTH_SPECTROGRAM_BACKEND
      return 0
      ;;
    --spectrogram-backend)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --spectrogram-backend requires auto|sox|ffmpeg|both" >&2
        return 1
      fi
      AUTH_SPECTROGRAM_BACKEND=$2
      AU_CONSUMED=2
      export AU_CONSUMED AUTH_SPECTROGRAM_BACKEND
      return 0
      ;;
  esac
  return 1
}

plugin_after_flags() {
  if [[ "${DELETE_SOURCE:-0}" -eq 1 || "${DELETE_EXISTING:-0}" -eq 1 ]]; then
    echo "Error: flac-authenticity is read-only; -d/-D are not supported" >&2
    return 1
  fi
  if [[ "${OVERWRITE:-0}" -eq 1 ]]; then
    echo "Error: flac-authenticity is read-only; -y is not supported" >&2
    return 1
  fi

  case "${AUTH_SPECTROGRAM_BACKEND}" in
    auto|sox|ffmpeg|both) ;;
    *)
      echo "Error: invalid --spectrogram-backend '${AUTH_SPECTROGRAM_BACKEND}' (auto|sox|ffmpeg|both)" >&2
      return 1
      ;;
  esac

  if [[ "${AUTH_SPECTROGRAM_ALL}" -eq 1 ]]; then
    AUTH_SPECTROGRAM=1
  fi

  if command -v sox >/dev/null 2>&1; then
    AUTH_HAVE_SOX=1
  fi
  if command -v mediainfo >/dev/null 2>&1; then
    AUTH_HAVE_MEDIAINFO=1
  fi

  if [[ "${AUTH_SPECTROGRAM}" -eq 1 ]]; then
    case "${AUTH_SPECTROGRAM_BACKEND}" in
      sox)
        if [[ "${AUTH_HAVE_SOX}" -ne 1 ]]; then
          echo "Error: --spectrogram-backend=sox but sox not found" >&2
          return 1
        fi
        ;;
      auto)
        if [[ "${AUTH_HAVE_SOX}" -ne 1 ]]; then
          AUTH_SPECTROGRAM_BACKEND=ffmpeg
        else
          AUTH_SPECTROGRAM_BACKEND=sox
        fi
        ;;
      both)
        if [[ "${AUTH_HAVE_SOX}" -ne 1 ]]; then
          echo "Error: --spectrogram-backend=both requires sox (ffmpeg is already required)" >&2
          return 1
        fi
        ;;
    esac
  fi

  export AUTH_STRICT AUTH_SPECTROGRAM AUTH_SPECTROGRAM_ALL \
    AUTH_SPECTROGRAM_BACKEND AUTH_HAVE_SOX AUTH_HAVE_MEDIAINFO
  return 0
}

plugin_require_deps() {
  require_cmds flac ffmpeg ffprobe metaflac flock od awk || return 1
  # sox / mediainfo optional — resolved in plugin_after_flags
  return 0
}

plugin_banner_extra() {
  local mode="authenticity (spectral + bit-depth)"
  [[ "${AUTH_STRICT:-0}" -eq 1 ]] && mode+="; strict"
  if [[ "${AUTH_SPECTROGRAM:-0}" -eq 1 ]]; then
    if [[ "${AUTH_SPECTROGRAM_ALL:-0}" -eq 1 ]]; then
      mode+="; spectrogram=${AUTH_SPECTROGRAM_BACKEND} (all)"
    else
      mode+="; spectrogram=${AUTH_SPECTROGRAM_BACKEND} (suspects)"
    fi
  fi
  if [[ "${AUTH_HAVE_MEDIAINFO:-0}" -eq 1 ]]; then
    mode+="; mediainfo"
  fi
  log_always "mode:      ${mode}"
}

plugin_export_env() {
  export AUTH_STRICT AUTH_SPECTROGRAM AUTH_SPECTROGRAM_ALL \
    AUTH_SPECTROGRAM_BACKEND AUTH_HAVE_SOX AUTH_HAVE_MEDIAINFO AU_CLEANUP_SKIP
}
