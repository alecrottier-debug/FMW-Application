#!/usr/bin/env bash
#
# Fox Mill Woods → TestFlight, one command.
#
# Prereqs (one-time):
#   1. Apple Developer Program membership ($99/yr) — required for distribution signing.
#   2. An App Store Connect app record for bundle id com.foxmillwoods.app.
#   3. An App Store Connect API key: App Store Connect → Users and Access →
#      Integrations → App Store Connect API → generate a key (App Manager role).
#      Download the AuthKey_XXXXXXXXXX.p8 (you can only download it once).
#
# Then export these (e.g. in your shell profile — NOT committed):
#   export ASC_KEY_ID=XXXXXXXXXX
#   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#   export ASC_KEY_PATH="$HOME/keys/AuthKey_XXXXXXXXXX.p8"
#
# Usage:
#   scripts/beta.sh            archive + upload to TestFlight
#   scripts/beta.sh export     archive + produce a .ipa only (drag into Transporter)
#
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="FoxMillWoods"
TEAM_ID="T8LQMMVLY9"
ARCHIVE="build/FoxMillWoods.xcarchive"
EXPORT_DIR="build/export"
MODE="${1:-upload}"
DEST="upload"; [ "$MODE" = "export" ] && DEST="export"

mkdir -p build

# Load local secrets (scripts/beta.env is git-ignored — safe place to paste your Issuer ID).
[ -f scripts/beta.env ] && . scripts/beta.env

echo "▸ Regenerating project…"
xcodegen generate >/dev/null

echo "▸ Archiving (Release)…"
xcodebuild -project FoxMillWoods.xcodeproj -scheme "$SCHEME" \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates clean archive

PLIST="build/ExportOptions.plist"
cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>${DEST}</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><true/>
</dict></plist>
PL

if [ "$DEST" = "upload" ]; then
  # Auto-find the key you dropped in scripts/private/ and derive the Key ID from its filename.
  ASC_KEY_PATH="${ASC_KEY_PATH:-$(ls -t scripts/private/AuthKey_*.p8 2>/dev/null | head -1 || true)}"
  if [ -n "${ASC_KEY_PATH:-}" ] && [ -z "${ASC_KEY_ID:-}" ]; then
    ASC_KEY_ID="$(basename "$ASC_KEY_PATH" .p8 | sed 's/^AuthKey_//')"
  fi
  # xcodebuild requires an ABSOLUTE key path.
  case "${ASC_KEY_PATH:-}" in /*) ;; ?*) ASC_KEY_PATH="$PWD/$ASC_KEY_PATH" ;; esac
  : "${ASC_KEY_PATH:?No API key. Drop AuthKey_XXXX.p8 in scripts/private/ (see its README).}"
  : "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID in scripts/beta.env (copy scripts/beta.env.example).}"
  echo "▸ Exporting + uploading to TestFlight…"
  xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$PLIST" -exportPath "$EXPORT_DIR" -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "$ASC_KEY_ID" \
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  echo "✓ Uploaded. It appears in App Store Connect → TestFlight after processing (~5–15 min)."
  echo "  Add testers (or turn on the public link) there, plus a one-line 'what to test'."
else
  echo "▸ Exporting .ipa…"
  xcodebuild -exportArchive -archivePath "$ARCHIVE" \
    -exportOptionsPlist "$PLIST" -exportPath "$EXPORT_DIR" -allowProvisioningUpdates
  echo "✓ IPA in $EXPORT_DIR — drag it into the Transporter app to upload."
fi
