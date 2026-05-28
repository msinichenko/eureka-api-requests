#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

if ! command -v rg >/dev/null 2>&1; then
  echo "error: ripgrep (rg) is required to lint this collection." >&2
  echo "Install it with your package manager, then rerun scripts/lint-bruno.sh." >&2
  exit 2
fi

failures=0

report() {
  local title="$1"
  local pattern="$2"
  local output

  output="$(rg -n --glob '*.bru' "$pattern" . 2>/dev/null || true)"

  if [[ -n "$output" ]]; then
    failures=$((failures + 1))
    echo
    echo "FAIL: $title"
    echo "$output"
  else
    echo "PASS: $title"
  fi
}

report_paths() {
  local title="$1"
  local pattern="$2"
  local output

  output="$(rg --files --glob '*.bru' | rg "$pattern" || true)"

  if [[ -n "$output" ]]; then
    failures=$((failures + 1))
    echo
    echo "FAIL: $title"
    echo "$output"
  else
    echo "PASS: $title"
  fi
}

uuid='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

echo "Linting Bruno collection..."

report \
  "No hardcoded UUIDs in request files; use {{variable}} placeholders" \
  "$uuid"

report \
  "No persisted global token writes" \
  'setGlobalEnvVar\([^)]*token[^)]*\{ *persist: *true'

report \
  "No common spelling mistakes in request names or content" \
  'keycloack|keyckloak|confg|migraition|remaping|maping|affliation|passowrd|appications|cliens|Update capabilities to rol'

report \
  "No obvious local test usernames or scratch app names" \
  'testuser[0-9]*|app-test|mstestinst'

report_paths \
  "No scratch, copied, or obsolete request filenames" \
  '(^|/)(TEST|New Request|test)\.bru$| Copy\.bru$| OLD\.bru$| TEMPLATE\.bru$'

if [[ "$failures" -gt 0 ]]; then
  echo
  echo "Lint failed with $failures category/categories of findings."
  exit 1
fi

echo
echo "Lint passed."
