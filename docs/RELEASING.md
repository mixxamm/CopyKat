# Releasing CopyKat

Pushing a tag like `v0.2.0` triggers the release workflow: it builds the app,
signs it with a Developer ID certificate, notarizes it with Apple, and
attaches the stapled `CopyKat.zip` to a GitHub release.

## One-time setup

The workflow needs five repository secrets (Settings > Secrets and variables >
Actions). Never commit any of these values.

| Secret | Value |
|---|---|
| `MACOS_CERT_P12` | Your "Developer ID Application" certificate with private key, exported from Keychain Access as a .p12 and base64-encoded (`base64 -i cert.p12 \| pbcopy`) |
| `MACOS_CERT_PASSWORD` | The password you chose when exporting the .p12 |
| `NOTARY_APPLE_ID` | The Apple ID email of your developer account |
| `NOTARY_PASSWORD` | An app-specific password, created at account.apple.com under Sign-In and Security |
| `APPLE_TEAM_ID` | Your ten-character Team ID, visible at developer.apple.com/account under Membership details |

If you don't have the certificate yet: Xcode > Settings > Accounts > Manage
Certificates > + > Developer ID Application, then find it in Keychain Access
and export it (right-click > Export, choose .p12).

## Cutting a release

```bash
git tag v0.2.0
git push origin v0.2.0
```

Watch the run under Actions. When it finishes, the release with the notarized
zip appears on the releases page.
