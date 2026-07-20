#!/usr/bin/env bash
# Cleanup less meaningful for multi-file CUE splits.
delete_one_existing() {
  log_progress "cleanup skip (cue→flac): $1"
  return 0
}
