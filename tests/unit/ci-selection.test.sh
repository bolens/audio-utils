#!/usr/bin/env bash
# Exercise the actual CI planner with disposable tool trees.
set -euo pipefail
# shellcheck source=../harness.sh
source "$(dirname "${BASH_SOURCE[0]}")/../harness.sh"

test_ci_tool_selection_preserves_coverage() {
  python3 - "$AU_REPO_ROOT/.github/workflows/ci.yml" "$T" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys
import textwrap

workflow = Path(sys.argv[1]).read_text()
planner = textwrap.dedent(workflow.split('      - name: Plan shellcheck matrices\n', 1)[1]
                         .split('        run: |\n', 1)[1].split('\n  shellcheck-lib:', 1)[0])
root = Path(sys.argv[2])
for path in ['conversion/a', 'conversion/nested/deep/b', 'util/category/a']:
    (root / path).mkdir(parents=True)
    (root / path / 'Makefile').touch()


def plan(files, shared='false'):
    output = root / 'output'
    output.write_text('')
    env = dict(os.environ, GITHUB_OUTPUT=str(output), LIB_CHANGED=shared,
               CONVERSION_CHANGED='true', UTIL_CHANGED='false',
               CONVERSION_FILES=files, UTIL_FILES='[]')
    result = subprocess.run(['bash', '-c', planner], cwd=root, env=env,
                            capture_output=True, text=True)
    outputs = dict(line.split('=', 1) for line in output.read_text().splitlines())
    return result, {key: json.loads(value) for key, value in outputs.items()}


all_tools = ['conversion/a', 'conversion/nested/deep/b']
for files, expected in [(['conversion/a/input'], ['conversion/a']),
                        (['conversion/shared.conf'], all_tools),
                        (['conversion/deleted/input'], all_tools),
                        (['conversion/a/line\nbreak'], all_tools)]:
    result, outputs = plan(json.dumps(files))
    assert result.returncode == 0, result.stderr
    assert outputs['conversion_tools'] == expected, outputs
result, outputs = plan('[]', 'true')
assert result.returncode == 0 and outputs['conversion_tools'] == all_tools
for invalid in ['', 'null', '{}', '[3]']:
    result, _ = plan(invalid)
    assert result.returncode != 0, invalid
PY
}

run_tests
