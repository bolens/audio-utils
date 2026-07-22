# lib/ — shared audio-utils library

All real logic lives here; per-tool directories carry only a thin CLI, a
`lib/plugin.sh` contract file, and small wrapper scripts.

## Where does new code go?

| Location | Contents | Put code here when… |
|---|---|---|
| `lib/` (root) | `load.sh`, `plugin_init.sh`, `tool.mk` | Never — these are fixed anchors that tools locate by walking up the tree. |
| `core/` | log, compat, xdg, config, version, util, tmpdir, progress, disk, delete, success_log | It is generic plumbing with no audio knowledge (logging, paths, config, temp dirs, deletion safety, success/failure logs). |
| `cli/` | cli, driver, worker, convert_all, run_parallel, find-audio-dirs | It is part of the shared CLI/driver stack: option parsing, queueing, parallel workers, directory discovery. |
| `media/` | probe, tags, audio_meta, audio_exts, pcm_flac, cue, chapters, playlist, lossless | It inspects or manipulates audio files/metadata but is not a conversion pipeline (ffprobe wrappers, tag copy, CUE/chapter/playlist parsing, FLAC integrity). |
| `pipeline/` | pcm_to_flac, pcm_to_flac_hooks, pcm_remux, lossy, lossy_hooks, tak, dvd, cdda, bluray | It implements a conversion pipeline or format/disc-specific encode logic shared by converters. |

## Loading

Tools never source modules directly. The chain is:

1. Tool entry script walks up to the repo root (marker: `lib/plugin_init.sh`)
   and sources `lib/cli/cli.sh`.
2. `cli/cli.sh` sources the tool's `lib/plugin.sh`.
3. `plugin.sh` sets the `AU_*` contract vars and sources `lib/plugin_init.sh`,
   which validates the contract and sources `lib/load.sh`.
4. `load.sh` sources every module above in dependency order.

Keep `load.sh` in sync when adding a module: source it there, in order, and
add a matching `# shellcheck source=` directive.

## Conventions

- Bash only (`#!/usr/bin/env bash`), `set -euo pipefail` in executables.
- Modules are source-only (no side effects beyond function/vars definitions);
  executables are `cli/find-audio-dirs.sh`, `cli/worker.sh`,
  `cli/run_parallel.sh`.
- Everything must pass `shellcheck -x -a` (run `make check-lib` from the
  repo root).
