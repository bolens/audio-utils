#!/usr/bin/env bash
# Match the repository's CI ShellCheck release on both supported architectures.
set -euo pipefail
version=v0.11.0
case "$(uname -m)" in
  x86_64) arch=x86_64; checksum=8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198 ;;
  aarch64|arm64) arch=aarch64; checksum=12b331c1d2db6b9eb13cfca64306b1b157a86eb69db83023e261eaa7e7c14588 ;;
  *) echo "Unsupported ShellCheck architecture" >&2; exit 1 ;;
esac
scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
curl -fsSL --retry 3 -o "$scratch/shellcheck.tar.xz" \
  "https://github.com/koalaman/shellcheck/releases/download/${version}/shellcheck-${version}.linux.${arch}.tar.xz"
printf '%s  %s\n' "$checksum" "$scratch/shellcheck.tar.xz" | sha256sum -c -
tar -xJf "$scratch/shellcheck.tar.xz" -C "$scratch"
install -m 0755 "$scratch/shellcheck-${version}/shellcheck" /usr/local/bin/shellcheck
shellcheck --version
