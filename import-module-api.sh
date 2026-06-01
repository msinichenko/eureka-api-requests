#!/usr/bin/env bash
set -euo pipefail

# import-module-api.sh
# Downloads OpenAPI specs from folio-org GitHub and imports them as Bruno requests.
# Requires: curl, unzip, bru (npm i -g @usebruno/cli), npx + @redocly/cli (auto-installed via npx)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SWAGGER_PATH="src/main/resources/swagger.api"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] <module> [<module>...]

Downloads OpenAPI specs from folio-org GitHub and imports them as Bruno requests.
Each imported module folder is added to .gitignore by default to keep it out of
the collection's version history. Use -g to opt out of that behaviour.

The full repository is downloaded as a ZIP archive (one request per module, no
GitHub API calls, no authentication required for public folio-org repos).

Options:
  -b <branch>    Branch to fetch from (default: master)
  -o <dir>       Output base directory (default: ./<module-name>/)
  -g             Do NOT add the imported folder to .gitignore
  -h             Show this help

Requirements:
  curl, unzip, bru (npm i -g @usebruno/cli), npx (bundled with Node.js)
  @redocly/cli is fetched automatically via npx on first run.

Examples:
  $(basename "$0") mod-scheduler
  $(basename "$0") mod-scheduler mod-search mod-users-keycloak
  $(basename "$0") -b main mod-scheduler
  $(basename "$0") -g mod-scheduler          # keep in git
EOF
  exit 0
}

die() { echo "error: $*" >&2; exit 1; }

command -v curl  >/dev/null 2>&1 || die "curl is required"
command -v unzip >/dev/null 2>&1 || die "unzip is required"
command -v bru   >/dev/null 2>&1 || die "Bruno CLI (bru) is required — npm i -g @usebruno/cli"
command -v npx   >/dev/null 2>&1 || die "npx is required (comes with Node.js/npm)"

branch="master"
output_base=""
no_gitignore=false

while getopts "b:o:gh" opt; do
  case $opt in
    b) branch="$OPTARG" ;;
    o) output_base="$OPTARG" ;;
    g) no_gitignore=true ;;
    h) usage ;;
    *) die "Unknown option -$OPTARG. Run with -h for help." ;;
  esac
done
shift $((OPTIND - 1))

[ $# -eq 0 ] && usage

add_to_gitignore() {
  local entry="/$1/"
  local gitignore="$SCRIPT_DIR/.gitignore"
  grep -qxF "$entry" "$gitignore" 2>/dev/null && return
  printf '\n# imported by import-module-api.sh\n%s\n' "$entry" >> "$gitignore"
  echo "  ↪ added $entry to .gitignore"
}

add_folio_headers() {
  local file="$1"
  if grep -q '^headers {' "$file"; then
    # headers block exists — fix empty/wrong values and add any missing entries
    awk '
      /^headers \{/ { in_headers=1; print; next }
      in_headers && /^\}/ {
        if (!token_seen)  print "  x-okapi-token: {{okapi-token}}"
        if (!tenant_seen) print "  x-okapi-tenant: {{realm}}"
        in_headers=0; print; next
      }
      in_headers && /x-okapi-token:/  { token_seen=1;  print "  x-okapi-token: {{okapi-token}}";  next }
      in_headers && /x-okapi-tenant:/ { tenant_seen=1; print "  x-okapi-tenant: {{realm}}"; next }
      { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  else
    # no headers block — insert one after the HTTP method block closing }
    awk '
      /^(get|post|put|delete|patch) \{/ { in_method=1 }
      in_method && /^\}/ {
        print
        print ""
        print "headers {"
        print "  x-okapi-token: {{okapi-token}}"
        print "  x-okapi-tenant: {{realm}}"
        print "}"
        in_method=0; next
      }
      { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
  fi
}

create_folder_bru() {
  local collection_dir="$1"
  local name
  name=$(basename "$collection_dir")
  cat > "$collection_dir/folder.bru" <<EOF
meta {
  name: $name
}

auth {
  mode: inherit
}

script:pre-request {
  const res = await bru.runRequest("auth/get-keycloak-tenant-token");
}
EOF
}

post_process_collection() {
  local collection_dir="$1"
  [ -d "$collection_dir" ] || return
  create_folder_bru "$collection_dir"
  while IFS= read -r -d '' bru_file; do
    local fname
    fname=$(basename "$bru_file")
    [[ "$fname" == "folder.bru" || "$fname" == "collection.bru" ]] && continue
    add_folio_headers "$bru_file"
  done < <(find "$collection_dir" -name "*.bru" -print0)
}

ok=0
fail=0

for module in "$@"; do
  echo ""
  echo "→ $module"

  out_dir="${output_base:-$SCRIPT_DIR/$module}"
  mkdir -p "$out_dir"

  tmp_dir=$(mktemp -d /tmp/folio-spec-XXXX)
  zip_file="$tmp_dir/$module.zip"
  zip_url="https://github.com/folio-org/$module/archive/refs/heads/$branch.zip"

  echo "  ↓ $module@$branch"
  if ! curl -fsSL --retry 3 --retry-delay 2 "$zip_url" -o "$zip_file"; then
    echo "  ✗ Download failed — check the module name and branch"
    rm -rf "$tmp_dir"
    (( fail++ )) || true
    continue
  fi

  echo "  ↓ extracting..."
  unzip -q "$zip_file" -d "$tmp_dir"

  # The ZIP extracts to {module}-{branch}/ (GitHub replaces / with - in branch names)
  spec_dir=$(find "$tmp_dir" -type d -name "swagger.api" 2>/dev/null | head -1)
  if [ -z "$spec_dir" ]; then
    echo "  ✗ No swagger.api directory found — module may use RAML or a different layout"
    rm -rf "$tmp_dir"
    (( fail++ )) || true
    continue
  fi

  mapfile -t specs < <(find "$spec_dir" -maxdepth 1 -name "*.yaml" -o -name "*.yml" -o -name "*.json" | xargs -I{} basename {} 2>/dev/null)
  if [ ${#specs[@]} -eq 0 ]; then
    echo "  ✗ No OpenAPI spec files found in swagger.api/"
    rm -rf "$tmp_dir"
    (( fail++ )) || true
    continue
  fi

  module_ok=true
  for spec in "${specs[@]}"; do
    source_file="$spec_dir/$spec"

    if grep -qE '^\s+\$ref:\s+[^#]' "$source_file"; then
      echo "  ⟳ bundling $spec..."
      bundled="$tmp_dir/_bundled_$spec"
      if ! npx --yes @redocly/cli bundle "$source_file" -o "$bundled" --force 2>&1; then
        echo "  ✗ Bundle failed for $spec"
        module_ok=false
        continue
      fi
      source_file="$bundled"
    fi

    echo "  ⟳ importing $spec..."
    if ! bru import openapi \
        --source "$source_file" \
        --output "$out_dir" \
        --collection-name "$module" \
        --collection-format bru 2>&1; then
      echo "  ✗ Import failed for $spec"
      module_ok=false
    fi
  done

  rm -rf "$tmp_dir"

  if $module_ok; then
    post_process_collection "$out_dir/$module"
    $no_gitignore || add_to_gitignore "$module"
    echo "  ✓ done → $out_dir"
    (( ok++ )) || true
  else
    (( fail++ )) || true
  fi
done

echo ""
echo "Summary: $ok imported, $fail failed."
