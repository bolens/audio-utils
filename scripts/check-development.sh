#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
make check
ruff check scripts/development-container.py scripts/ci/woodpecker-publish.py tests/test_publication_policy.py tests/test_development_container.py
python3 -m unittest discover -s tests -p test_development_container.py -v
if [[ $(uname -s) == Linux ]]; then
  npm ci --prefix mcp/npm --ignore-scripts --no-audit --no-fund
  npm test --prefix mcp/npm
  make test-all JOBS="${JOBS:-4}"
else
  echo "Native macOS: lint and adapter checks only; run Linux media tests in a container."
fi

python3 -m unittest discover -s tests -p test_publication_policy.py
