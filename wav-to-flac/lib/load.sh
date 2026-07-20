#!/usr/bin/env bash
# Back-compat shim — prefer plugin.sh for new code.
# shellcheck source=plugin.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/plugin.sh"
