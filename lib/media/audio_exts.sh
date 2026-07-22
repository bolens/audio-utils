#!/usr/bin/env bash
# Shared audio extension lists for multi-format utils and find presets.
# Source this before setting AU_SOURCE_EXTS when a tool uses a standard cluster.
# Prefer these (or a documented subset) — do not invent another portable list.

# Portable + common archive lossy/lossless tags targets (no PCM containers).
AU_AUDIO_EXTS_DEFAULT="flac mp3 opus m4a ogg oga wma mpc spx aac"
# PCM containers commonly paired with the portable set.
AU_AUDIO_EXTS_PCM="wav aiff aif caf"
# Lossy-only (library-prune / lossy-audit / lossy-to-flac).
AU_AUDIO_EXTS_LOSSY="mp3 opus m4a ogg oga wma mpc spx aac"
# Extra lossless archive containers (playlist-generate, audio-compare, library sweep).
AU_AUDIO_EXTS_ARCHIVE="wv ape tak tta"
# Sidecar / library metadata files (path-audit, perms, junk).
AU_AUDIO_EXTS_SIDECAR="cue m3u m3u8 pls xspf jpg jpeg png log"
# Playlist containers only (playlist-audit / normalize / dedupe / export).
AU_AUDIO_EXTS_PLAYLIST="m3u m3u8 pls xspf"
# Finder junk markers (junk-cleanup only; not audio).
AU_AUDIO_EXTS_JUNK="db ini ds_store directory"
# Spectrogram / waveform export set (sox-friendly PCM + common lossy; not full portable).
AU_AUDIO_EXTS_VIZ="flac wav aiff aif caf mp3 opus m4a ogg oga"

# Print space-separated exts for a named preset, or return 1 if unknown.
# Presets:
#   portable | portable-pcm | pcm | lossy
#   portable-pcm-archive | library | library-junk | viz | playlist
au_audio_exts_for_preset() {
  case "${1:-}" in
    portable) printf '%s' "$AU_AUDIO_EXTS_DEFAULT" ;;
    portable-pcm) printf '%s %s' "$AU_AUDIO_EXTS_DEFAULT" "$AU_AUDIO_EXTS_PCM" ;;
    pcm) printf '%s' "$AU_AUDIO_EXTS_PCM" ;;
    lossy) printf '%s' "$AU_AUDIO_EXTS_LOSSY" ;;
    portable-pcm-archive)
      printf '%s %s %s' "$AU_AUDIO_EXTS_DEFAULT" "$AU_AUDIO_EXTS_PCM" "$AU_AUDIO_EXTS_ARCHIVE"
      ;;
    library)
      printf '%s %s %s %s' "$AU_AUDIO_EXTS_DEFAULT" "$AU_AUDIO_EXTS_PCM" \
        "$AU_AUDIO_EXTS_ARCHIVE" "$AU_AUDIO_EXTS_SIDECAR"
      ;;
    library-junk)
      printf '%s %s %s %s %s' "$AU_AUDIO_EXTS_JUNK" "$AU_AUDIO_EXTS_DEFAULT" \
        "$AU_AUDIO_EXTS_PCM" "$AU_AUDIO_EXTS_ARCHIVE" "$AU_AUDIO_EXTS_SIDECAR"
      ;;
    viz) printf '%s' "$AU_AUDIO_EXTS_VIZ" ;;
    playlist) printf '%s' "$AU_AUDIO_EXTS_PLAYLIST" ;;
    *) return 1 ;;
  esac
}
