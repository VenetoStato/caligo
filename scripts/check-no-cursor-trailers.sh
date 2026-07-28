#!/usr/bin/env bash
set -euo pipefail
pattern='^(Co-authored-by:[[:space:]]*Cursor|Made-with:[[:space:]]*Cursor)'
matches="$(git log --format=%B | grep -Eih "$pattern" || true)"
if [[ -n "${matches}" ]]; then
  echo "FAIL: found Cursor trailers in git history:" >&2
  echo "$matches" >&2
  exit 1
fi
echo "OK: no Cursor Co-authored-by / Made-with trailers found."