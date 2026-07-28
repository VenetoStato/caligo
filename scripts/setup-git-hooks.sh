#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
git config core.hooksPath "$ROOT/.githooks"
chmod +x "$ROOT/.githooks/commit-msg" "$ROOT/scripts/check-no-cursor-trailers.sh" 2>/dev/null || true
echo "Configured core.hooksPath=$ROOT/.githooks"