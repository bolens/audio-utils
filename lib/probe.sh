#!/usr/bin/env bash
# ffmpeg/ffprobe probes and hashing helpers.

audio_md5() {
  ffmpeg -v error -i "$1" -map 0:a:0 -f md5 - | sed 's/^MD5=//'
}

file_sha256() {
  sha256sum -- "$1" | awk '{print $1}'
}

audio_codec() {
  ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 -- "$1" 2>/dev/null
}

audio_samples() {
  ffprobe -v error -select_streams a:0 -show_entries stream=duration_ts -of csv=p=0 -- "$1" 2>/dev/null
}

# Duration in seconds (float), empty on failure.
audio_duration_sec() {
  ffprobe -v error -select_streams a:0 -show_entries stream=duration -of csv=p=0 -- "$1" 2>/dev/null
}

# Bits per sample (raw preferred). Empty on failure.
audio_bits_per_sample() {
  local b
  b=$(ffprobe -v error -select_streams a:0 -show_entries stream=bits_per_raw_sample -of csv=p=0 -- "$1" 2>/dev/null)
  if [[ -z "$b" || "$b" == "N/A" || "$b" == "0" ]]; then
    b=$(ffprobe -v error -select_streams a:0 -show_entries stream=bits_per_sample -of csv=p=0 -- "$1" 2>/dev/null)
  fi
  if [[ -z "$b" || "$b" == "N/A" || "$b" == "0" ]]; then
    return 1
  fi
  printf '%s\n' "$b"
}

file_bytes() {
  stat -c%s -- "$1" 2>/dev/null || echo 0
}

# Max abs sample level + NaN/Inf guard via ffmpeg astats (normalized float domain).
float_abs_peak() {
  local report nans infs
  report=$(ffmpeg -hide_banner -i "$1" -map 0:a:0 -af astats -f null - 2>&1) || return 1
  nans=$(printf '%s\n' "$report" | awk '/Number of NaNs:/ {s+=$NF} END {print s+0}')
  infs=$(printf '%s\n' "$report" | awk '/Number of Infs:/ {s+=$NF} END {print s+0}')
  if ((nans > 0 || infs > 0)); then
    log_err "NANINF nans=$nans infs=$infs"
    return 1
  fi
  printf '%s\n' "$report" | awk '
    /Min level:/ { v=$NF; if (v<0) v=-v; if (v>m) m=v }
    /Max level:/ { v=$NF; if (v<0) v=-v; if (v>m) m=v }
    END { if (m=="") exit 1; printf "%.10f\n", m }'
}
