# Releasing

Pushing a `v*` tag triggers `.github/workflows/release.yml`, which builds a DMG
and attaches it to the matching GitHub Release (creating it if needed).

```bash
# bump the version in scripts/AppInfo.plist first, then:
git tag v0.2.0 && git push origin v0.2.0   # push to the GitHub remote
```

## Signed + notarized releases (optional)

Without secrets, CI produces an ad-hoc-signed DMG (users must clear quarantine).
To ship a signed, notarized DMG automatically, add these repository secrets
(Settings → Secrets and variables → Actions):

| Secret | What it is |
|---|---|
| `MACOS_CERT_P12` | base64 of your exported "Developer ID Application" .p12 |
| `MACOS_CERT_PASSWORD` | password for that .p12 |
| `MACOS_SIGN_IDENTITY` | e.g. `Developer ID Application: Your Name (TEAMID)` |
| `NOTARY_APPLE_ID` | Apple ID used for notarization |
| `NOTARY_TEAM_ID` | Apple Developer Team ID |
| `NOTARY_PASSWORD` | app-specific password for notarization |
| `SPARKLE_PRIVATE_KEY` | Sparkle EdDSA private key used to sign appcast entries |

Export the cert: `security export` / Keychain Access → export the Developer ID
Application identity as .p12, then `base64 -i cert.p12 | pbcopy`.

Create the app-specific password at Apple ID → Sign-In & Security.

The release workflow publishes `docs/appcast.xml` for Sparkle after uploading
the DMG. Without `SPARKLE_PRIVATE_KEY`, GitHub Releases still publish, but the
in-app updater has no signed release item to offer.

Locally, you can still run `./scripts/release.sh` which uses a stored notarytool
keychain profile instead of API-key secrets.
