# Releasing AudioXplorer

How to ship a new version end‑to‑end: signed, notarized DMG on GitHub Releases plus a refreshed Sparkle appcast for in‑app auto‑updates.

## Prerequisites (one‑time per machine)

You'll need:

- **Xcode** (a recent version) and Command Line Tools.
- **An Apple Developer account** with a `Developer ID Application` certificate in your login keychain.
- **`create-dmg`**: `brew install create-dmg`.
- **A `notarytool` keychain profile.** Generate an app‑specific password at <https://appleid.apple.com> → Sign‑In and Security → App‑Specific Passwords, then:
  ```bash
  xcrun notarytool store-credentials YOUR_PROFILE_NAME \
      --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID
  ```
  AudioXplorer's `scripts/release.sh` defaults to a profile named `AX_NOTARY`; override with `NOTARY_PROFILE=…`.
- **Sparkle EdDSA private key** in your login keychain. If this is a fresh machine, restore it from your password manager and re‑import:
  ```bash
  scripts/sparkle/generate_keys -f /path/to/key/file
  ```
- **Push access** to the repo (so you can publish the appcast and create the Release).

## Cutting a release

1. **Bump the version** in `Info.plist`: increment `CFBundleShortVersionString` (e.g. `1.4` → `1.5`) and `CFBundleVersion` (e.g. `127` → `128`).

2. **Write release notes** at `docs/releasenotes/<CFBundleShortVersionString>.md` (Markdown). The release script copies this file alongside the DMG so `generate_appcast` embeds it as the appcast item's `<description>`, which is what Sparkle's update prompt displays. If the file is missing, the script warns and produces an item with no description.

3. **Run the release script.** Set `SIGN_ID` to the full identity string if you have multiple Developer ID certs:
   ```bash
   SIGN_ID="Developer ID Application: Your Name (TEAMID)" ./scripts/release.sh
   ```
   The script will:
   - `xcodebuild` Release into `build/Release/`
   - Sign the `.app` with hardened runtime
   - Package a DMG into `dist/` via `create-dmg`
   - Sign the DMG
   - Submit to Apple's notary service and `wait` (~3–5 min)
   - Staple the ticket
   - Regenerate `docs/appcast.xml` with EdDSA signatures via `scripts/sparkle/generate_appcast`

   For a quick packaging-only test (no notarization round-trip), use `SKIP_NOTARIZE=1`.

4. **Sanity-check the artifacts.**
   ```bash
   open dist/AudioXplorer-X.Y.dmg              # visual layout check
   git diff docs/appcast.xml                    # confirm new <item> for X.Y, EdDSA signature populated
   ```

5. **Commit, tag, push.**
   ```bash
   git add Info.plist docs/appcast.xml docs/releasenotes/X.Y.md
   git commit -m "Release X.Y"
   git tag -a vX.Y -m "AudioXplorer X.Y"
   git push origin main --tags
   ```

6. **Create the GitHub Release.** The appcast's enclosure URL points at `https://github.com/jean-bovet/AudioXplorer/releases/download/vX.Y/AudioXplorer-X.Y.dmg`, so the asset filename and tag name must match:
   ```bash
   gh release create vX.Y dist/AudioXplorer-X.Y.dmg \
       --title "AudioXplorer X.Y" \
       --notes "Release notes…"
   ```

## Verification

After publishing, confirm the update path actually works:

1. **Appcast served**:
   ```bash
   curl -sI https://jean-bovet.github.io/AudioXplorer/appcast.xml
   # → HTTP/2 200, content-type: application/xml
   ```
2. **DMG reachable** via the URL inside the appcast — should `302` to GitHub's CDN and return the correct `content-length`.
3. **End-to-end Sparkle prompt**: revert your local `Info.plist` to a *lower* version, rebuild, launch, click "Check For Update…". Sparkle should prompt with the new version's release notes and successfully install.

## Common pitfalls

- **`notarytool` rejects the submission** — fetch the log to see why:
  ```bash
  xcrun notarytool log <submission-id> --keychain-profile YOUR_PROFILE_NAME
  ```
  The most common cause we've hit is a nested bundle (e.g. a plug-in) that isn't signed with your Developer ID. Re-sign that bundle and re-run.
- **`generate_appcast` not found** — the Sparkle CLI tools live in `scripts/sparkle/`, not inside `Frameworks/Sparkle.framework`. The release script knows the right path; if you invoke `generate_appcast` manually, point at `scripts/sparkle/generate_appcast`.
- **Sparkle reports "you're up to date" after publishing** — the appcast version must be strictly greater than the locally installed `CFBundleShortVersionString`. Bump *both* the short version and the build number when releasing.
- **Tag/asset name mismatch** — the appcast bakes in the URL `…/releases/download/vX.Y/AudioXplorer-X.Y.dmg`. If your tag is `release-1.5` or your DMG is `AudioXplorer_1.5.dmg`, Sparkle's download will 404. Stick to `vX.Y` and `AudioXplorer-X.Y.dmg`.
- **Hardened-runtime crash on launch in CI** — verify `LD_RUNPATH_SEARCH_PATHS` still includes `@executable_path/../Frameworks` and that the entitlements file at `AudioXplorer.entitlements` is referenced by every build configuration.

## What to do if you lose the Sparkle private key

Existing 1.x installs verify updates against the public key baked into their `Info.plist`. If you sign a new release with a different key, those installs will reject it. Recovery options, in order of preference:

1. **Restore the key** from your password manager into the login keychain (`generate_keys -f`).
2. **Generate a new key**, embed the new public key, and ship the next release manually (users have to download it from GitHub Releases). Future updates from that point onward use the new key.

There is no "Sparkle key rotation" feature in 2.x — once shipped, the public key is what existing installs trust.

## Files involved

- `scripts/release.sh` — orchestrates the whole pipeline.
- `scripts/sparkle/{generate_appcast,sign_update,generate_keys}` — vendored Sparkle CLI tools.
- `Frameworks/Sparkle.framework/` — vendored Sparkle 2 runtime.
- `AudioXplorer.entitlements` — hardened-runtime entitlements (includes `com.apple.security.cs.disable-library-validation` so Sparkle's bundled XPC services load).
- `Info.plist` — `SUFeedURL`, `SUPublicEDKey`, `SUEnableAutomaticChecks`, plus the version fields.
- `docs/appcast.xml` — published via GitHub Pages from the `/docs` folder of `main`.
