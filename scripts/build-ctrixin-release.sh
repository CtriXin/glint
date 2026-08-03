#!/usr/bin/env bash
# Build a local CtriTerm release with a stable Developer ID identity.
#
# Required:
#   DEVELOPMENT_TEAM       Apple Team ID used by the local Developer ID cert
# Optional:
#   CODESIGN_IDENTITY      Defaults to the first local Developer ID Application identity
#   VERSION                Defaults to a local prerelease derived from the git revision
#   BUILD_NUMBER           Defaults to UTC YYYYMMDDHHMM
#   NOTARY_KEYCHAIN_PROFILE  An xcrun notarytool keychain profile; enables notarization
#   ARCHIVE_PATH           Output .xcarchive location (must not already exist)
#
# Credentials stay in the login keychain. Do not put certificate exports,
# Apple IDs, app-specific passwords, or Sparkle private keys in this repository.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

: "${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to your Apple Team ID.}"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
else
  # The checked-in project is kept in sync with project.yml so a normal local
  # release does not require installing another generator tool. Install and
  # run xcodegen before a future project.yml structural change.
  echo "xcodegen not installed; using the checked-in Glint.xcodeproj."
fi

if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
  CODESIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' \
    | head -n 1)"
fi
if [[ -z "$CODESIGN_IDENTITY" ]]; then
  echo "ERROR: no Developer ID Application identity is available in the login keychain." >&2
  exit 1
fi

VERSION="${VERSION:-0.1.27-ctrixin.$(git rev-list --count HEAD)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/CtriTerm-${VERSION}.xcarchive}"

if [[ -e "$ARCHIVE_PATH" ]]; then
  echo "ERROR: archive already exists: $ARCHIVE_PATH" >&2
  echo "Choose ARCHIVE_PATH rather than overwriting an existing build." >&2
  exit 1
fi

xcodebuild \
  -project Glint.xcodeproj \
  -scheme Glint \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$CODESIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  archive

APP="$ARCHIVE_PATH/Products/Applications/CtriTerm.app"
if [[ ! -d "$APP" ]]; then
  echo "ERROR: archive did not contain the expected app: $APP" >&2
  exit 1
fi

scripts/verify-ghostty-resources.sh "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -dvv "$APP"
plutil -extract CFBundleIdentifier raw "$APP/Contents/Info.plist"

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  ZIP="$ARCHIVE_PATH.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  rm -f "$ZIP"
else
  echo "Signed but not notarized. Set NOTARY_KEYCHAIN_PROFILE to notarize and staple this build."
fi

echo "Local release ready: $APP"
