#!/usr/bin/env bash
# Package an already-notarized CtriTerm app for public GitHub distribution.
# The output contains no signing credentials, source checkout, or local state.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP="${1:?usage: scripts/package-public-release.sh <CtriTerm.app> <version> [output-dir]}"
VERSION="${2:?usage: scripts/package-public-release.sh <CtriTerm.app> <version> [output-dir]}"
OUTPUT_DIR="${3:-$ROOT/dist}"

if [[ ! -d "$APP" ]]; then
  echo "ERROR: app does not exist: $APP" >&2
  exit 1
fi

for NOTICE in LICENSES/Glint-MIT.txt LICENSES/Ghostty-MIT.txt LICENSES/Sparkle-LICENSE.txt \
  THIRD_PARTY_NOTICES.md RELEASE_INSTALL.md
 do
  if [[ ! -f "$NOTICE" ]]; then
    echo "ERROR: required public-release notice is missing: $NOTICE" >&2
    exit 1
  fi
done

PACKAGE_NAME="CtriTerm-${VERSION}-macos-arm64"
ZIP="$OUTPUT_DIR/${PACKAGE_NAME}-notarized.zip"
CHECKSUM="$ZIP.sha256"
if [[ -e "$ZIP" || -e "$CHECKSUM" ]]; then
  echo "ERROR: refusing to overwrite existing artifact: $ZIP" >&2
  exit 1
fi

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
PACKAGE_ROOT="$STAGING/$PACKAGE_NAME"
mkdir -p "$PACKAGE_ROOT/LICENSES"

ditto "$APP" "$PACKAGE_ROOT/CtriTerm.app"
cp THIRD_PARTY_NOTICES.md RELEASE_INSTALL.md "$PACKAGE_ROOT/"
cp LICENSES/Glint-MIT.txt LICENSES/Ghostty-MIT.txt LICENSES/Sparkle-LICENSE.txt "$PACKAGE_ROOT/LICENSES/"

mkdir -p "$OUTPUT_DIR"
ditto -c -k --keepParent "$PACKAGE_ROOT" "$ZIP"
shasum -a 256 "$ZIP" > "$CHECKSUM"

printf 'Public release ZIP: %s\nChecksum: %s\n' "$ZIP" "$CHECKSUM"
