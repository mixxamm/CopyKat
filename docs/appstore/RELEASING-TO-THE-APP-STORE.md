# Getting a build into App Store Connect

The App Store build is the `CopyKat-MAS` target: sandboxed, no Sparkle, signed
for the store. Two ways to get it uploaded.

## Option A: Xcode Cloud (no local signing work)

The repository has no `.xcodeproj`; it is generated from `project.yml`.
`ci_scripts/ci_post_clone.sh` runs XcodeGen right after Xcode Cloud clones the
repo, so the scheme exists before the build starts. That part is already in
place.

What you do once, in Xcode:

1. Product > Xcode Cloud > Create Workflow.
2. Pick the **CopyKat-MAS** scheme.
3. Grant access to the GitHub repository when asked.
4. Set the start condition to a branch change on `main`, or to a tag if you
   prefer to release deliberately.
5. Add the action **Archive** with destination **App Store Connect**, platform
   macOS.
6. Save and run it.

Xcode Cloud signs the build with a managed distribution certificate, so you do
not need to create one yourself. When the run finishes the build appears under
the app's TestFlight and Distribution tabs.

## Option B: upload from your Mac

Needs an Apple Distribution certificate and an App Store Connect API key
(Users and Access > Integrations > App Store Connect API).

```bash
xcodegen generate
xcodebuild -scheme CopyKat-MAS -configuration Release \
  -archivePath build/CopyKat.xcarchive archive
```

```bash
xcodebuild -exportArchive -archivePath build/CopyKat.xcarchive \
  -exportOptionsPlist docs/appstore/ExportOptions.plist \
  -exportPath build/export \
  -authenticationKeyPath ~/private_keys/AuthKey_XXXX.p8 \
  -authenticationKeyID XXXX -authenticationKeyIssuerID YYYY
```

`ExportOptions.plist` is set to `app-store-connect` with `destination: upload`,
so the second command uploads straight to App Store Connect.

## After the upload

1. Wait for the build to finish processing (usually a few minutes).
2. In App Store Connect, attach the build to version 1.0.
3. Fill in the metadata from `METADATA.md` and upload the screenshots.
4. Answer the privacy questions: no data collected.
5. Paste the review notes from `METADATA.md`, they explain the Accessibility
   permission, which is the most likely thing a reviewer will ask about.
6. Submit.
