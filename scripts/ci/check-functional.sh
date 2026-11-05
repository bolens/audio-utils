#!/usr/bin/env bash
# Run the existing two functional shards using tracked source and isolated state.
set -euo pipefail
root=$(git rev-parse --show-toplevel)
cd -- "$root"
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
mkdir -p "$scratch/source" "$scratch/home" "$scratch/tmp"
# Match the remote adapter: never transfer ignored configuration or credentials.
git ls-files -z | tar --null --verbatim-files-from -T - -cf - | tar -xf - -C "$scratch/source"
runner=()
if [[ $(id -u) == 0 ]]; then
    chown -hR 10001:10001 "$scratch"
    runner=(setpriv --reuid=10001 --regid=10001 --clear-groups)
fi
"${runner[@]}" env HOME="$scratch/home" TMPDIR="$scratch/tmp" \
    XDG_CONFIG_HOME="$scratch/home/config" XDG_CACHE_HOME="$scratch/home/cache" \
    XDG_STATE_HOME="$scratch/home/state" LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    bash -s -- "$scratch/source" <<'RUN'
set -euo pipefail
cd -- "$1"
# Preserve the current best-effort optional-codec contract and bounded skip gate.
if ! bash scripts/ape-codec.sh install --prefix "$HOME/codecs"; then
    echo 'Optional APE installation unavailable; functional skips remain gated.' >&2
fi
if ! bash scripts/keyfinder-cli.sh install --prefix "$HOME/codecs"; then
    echo 'Optional keyfinder installation unavailable; functional skips remain gated.' >&2
fi
export PATH="$HOME/codecs/bin:$PATH"
export LD_LIBRARY_PATH="$HOME/codecs/lib:$HOME/codecs/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mapfile -t files < <(bash tests/run.sh --list functional)
((${#files[@]} > 0))
for shard in 0 1; do
    mine=()
    for i in "${!files[@]}"; do
        if ((i % 2 == shard)); then mine+=("${files[$i]}"); fi
    done
    ((${#mine[@]} > 0)) || continue
    status=0
    bash tests/run.sh "${mine[@]}" 2>&1 | tee "$TMPDIR/functional-$shard.log" || status=$?
    skips=$(grep -c '# SKIP' "$TMPDIR/functional-$shard.log" || true)
    unexpected=0
    while IFS= read -r line; do
        case "$line" in
            *'missing dependency:'*|*'ffmpeg lacks'*|*'no fpcalc'*|*'no python3'*|\
            *'no mac binary'*|*'no mpcenc'*|*'no bpm'*|*'no rsgain'*|\
            *'no C++ compiler'*|*'running as root'*|*'fixture build failed'*|*'sox lacks dff'*) ;;
            *) echo "Unexpected functional skip: $line" >&2; unexpected=1 ;;
        esac
    done < <(grep '# SKIP' "$TMPDIR/functional-$shard.log" || true)
    printf 'Functional shard %s/2: %s skips (maximum 10)\n' "$shard" "$skips"
    ((status == 0 && unexpected == 0 && skips <= 10)) || exit 1
done
RUN
