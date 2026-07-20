#!/usr/bin/env bash
# Decode FLAC → WAV + tag/cover — thin wrappers over lib/pcm_flac.sh.

target_wav_codec() {
  target_pcm_le_codec "$1"
}

tag_wav() {
  tag_pcm_from_flac "$1" "$2" "$3"
}

wav_ok() {
  pcm_ok "$1"
}
