#!/usr/bin/env bash
# Shared audio extension lists for multi-format utils and find presets.
# Source this before setting AU_SOURCE_EXTS when a tool uses a standard cluster.
# Prefer these (or a documented subset) — do not invent a fourth portable list.

# Portable + common archive lossy/lossless tags targets (no PCM containers).
AU_AUDIO_EXTS_DEFAULT="flac mp3 opus m4a ogg oga wma mpc spx aac"
# PCM containers commonly paired with the portable set.
AU_AUDIO_EXTS_PCM="wav aiff aif caf"
# Lossy-only (library-prune / lossy-audit).
AU_AUDIO_EXTS_LOSSY="mp3 opus m4a ogg oga wma mpc spx aac"

# Print space-separated exts for a named preset, or return 1 if unknown.
# Presets: portable | portable-pcm | pcm | lossy
au_audio_exts_for_preset() {
  case "${1:-}" in
    portable) printf '%s' "$AU_AUDIO_EXTS_DEFAULT" ;;
    portable-pcm) printf '%s %s' "$AU_AUDIO_EXTS_DEFAULT" "$AU_AUDIO_EXTS_PCM" ;;
    pcm) printf '%s' "$AU_AUDIO_EXTS_PCM" ;;
    lossy) printf '%s' "$AU_AUDIO_EXTS_LOSSY" ;;
    *) return 1 ;;
  esac
}
