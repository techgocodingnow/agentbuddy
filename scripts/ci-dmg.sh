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
    echo "==> Signing with Developer ID (inside-out, hardened runtime)"
    # Sign nested dylibs, XPC services, and sub-apps before the outer bundle.
    # Sparkle bundles several XPC helpers; they must carry the same identity or
    # Apple's notary rejects the submission.
    find "$APP/Contents" -depth \( -name "*.dylib" -o -name "*.xpc" -o -name "*.app" \) \
        -exec codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" {} \;
    find "$APP/Contents" -depth -name "*.framework" \
        -exec codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" {} \;
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
    set +e
    NOTARY_JSON=$(xcrun notarytool submit "$DMG" \
        --apple-id "$NOTARY_APPLE_ID" \
        --team-id "$NOTARY_TEAM_ID" \
        --password "$NOTARY_PASSWORD" \
        --wait --output-format json 2>&1)
    NOTARY_EXIT=$?
    set -e
    echo "$NOTARY_JSON"
    if [ $NOTARY_EXIT -ne 0 ]; then
        SUBMISSION_ID=$(echo "$NOTARY_JSON" \
            | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)
        if [ -n "$SUBMISSION_ID" ]; then
            echo "==> Fetching notarization log for $SUBMISSION_ID ..."
            xcrun notarytool log "$SUBMISSION_ID" \
                --apple-id "$NOTARY_APPLE_ID" \
                --team-id "$NOTARY_TEAM_ID" \
                --password "$NOTARY_PASSWORD" || true
        fi
        echo "ERROR: Notarization failed (exit $NOTARY_EXIT)" >&2
        exit 1
    fi
    xcrun stapler staple "$DMG"
fi

echo "==> Built $DMG"
shasum -a 256 "$DMG"
