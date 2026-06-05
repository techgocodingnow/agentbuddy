#!/usr/bin/env bash
# Builds AgentBuddy.app and a DMG. Signs with a Developer ID and notarizes when
# the corresponding env vars (from CI secrets) are present; otherwise produces
# an ad-hoc-signed DMG. Used by .github/workflows/release.yml.
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/AgentBuddy.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' scripts/AppInfo.plist)"

./scripts/build-app.sh release

if [ -n "${SIGN_IDENTITY:-}" ]; then
    echo "==> Signing with Developer ID (hardened runtime)"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/agentbuddy"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
    codesign --verify --strict "$APP"
fi

DMG="build/AgentBuddy-$VERSION.dmg"
STAGE="build/dmg"
rm -f "$DMG"; rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/AgentBuddy.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "AgentBuddy" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

if [ -n "${SIGN_IDENTITY:-}" ]; then
    echo "==> Signing DMG"
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

if [ -n "${NOTARY_APPLE_ID:-}" ] && [ -n "${NOTARY_TEAM_ID:-}" ] && [ -n "${NOTARY_PASSWORD:-}" ]; then
    echo "==> Notarizing DMG"
    xcrun notarytool submit "$DMG" \
        --apple-id "$NOTARY_APPLE_ID" \
        --team-id "$NOTARY_TEAM_ID" \
        --password "$NOTARY_PASSWORD" \
        --wait
    xcrun stapler staple "$DMG"
fi

echo "==> Built $DMG"
shasum -a 256 "$DMG"
