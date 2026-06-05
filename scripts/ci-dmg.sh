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
    # Pass 1: sign every Mach-O file individually (catches bare binaries like
    # Sparkle's 'Autoupdate' that have no extension and are missed by name globs).
    while IFS= read -r f; do
        if file "$f" 2>/dev/null | grep -q "Mach-O"; then
            codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$f"
        fi
    done < <(find "$APP/Contents" -type f)
    # Pass 2: sign bundles and frameworks inside-out, then the outer .app.
    find "$APP/Contents" -depth \( -name "*.xpc" -o -name "*.app" \) \
        -exec codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" {} \;
    find "$APP/Contents" -depth -name "*.framework" \
        -exec codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" {} \;
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
    # notarytool exits 0 even for "Invalid" status, so parse the JSON.
    NOTARY_STATUS=$(echo "$NOTARY_JSON" \
        | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
    if [ "$NOTARY_STATUS" != "Accepted" ]; then
        SUBMISSION_ID=$(echo "$NOTARY_JSON" \
            | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)
        if [ -n "$SUBMISSION_ID" ]; then
            echo "==> Fetching notarization log for $SUBMISSION_ID ..."
            xcrun notarytool log "$SUBMISSION_ID" \
                --apple-id "$NOTARY_APPLE_ID" \
                --team-id "$NOTARY_TEAM_ID" \
                --password "$NOTARY_PASSWORD" || true
        fi
        echo "ERROR: Notarization status: $NOTARY_STATUS" >&2
        exit 1
    fi
    xcrun stapler staple "$DMG"
fi

echo "==> Built $DMG"
shasum -a 256 "$DMG"
