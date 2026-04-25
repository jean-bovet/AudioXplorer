#!/usr/bin/env bash
set -euo pipefail

# Build, sign, notarize, and package AudioXplorer as a distributable DMG.
#
# Requirements:
#   - Xcode command line tools
#   - create-dmg:           brew install create-dmg
#   - A "Developer ID Application" certificate in your login keychain
#   - A notarytool keychain profile (one-time setup below)
#
# One-time notarytool setup (stores credentials in the keychain):
#   xcrun notarytool store-credentials AX_NOTARY \
#       --apple-id you@example.com \
#       --team-id YOURTEAMID \
#       --password <app-specific-password>
#
# Usage:
#   ./scripts/release.sh                    # build + sign + notarize
#   SKIP_NOTARIZE=1 ./scripts/release.sh    # local test build, no notarization

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="AudioXplorer"
SCHEME="AudioXplorer"
CONFIG="Release"
BUILD_DIR="$PROJECT_DIR/build"
RELEASE_DIR="$BUILD_DIR/$CONFIG"
APP_PATH="$RELEASE_DIR/$APP_NAME.app"
DIST_DIR="$PROJECT_DIR/dist"

SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AX_NOTARY}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PROJECT_DIR/Info.plist")
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

echo "==> Building $APP_NAME $VERSION ($CONFIG)"
xcodebuild \
    -project "$APP_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CONFIGURATION_BUILD_DIR="$RELEASE_DIR" \
    clean build

if [[ ! -d "$APP_PATH" ]]; then
    echo "error: $APP_PATH not found after build" >&2
    exit 1
fi

echo "==> Signing app with hardened runtime"
codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

echo "==> Creating DMG"
create-dmg \
    --volname "$APP_NAME $VERSION" \
    --window-size 540 360 \
    --icon-size 96 \
    --icon "$APP_NAME.app" 140 180 \
    --app-drop-link 400 180 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH"

echo "==> Signing DMG"
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"

if [[ "${SKIP_NOTARIZE:-0}" == "1" ]]; then
    echo "==> SKIP_NOTARIZE=1, skipping notarization"
    echo "Built: $DMG_PATH"
    exit 0
fi

echo "==> Submitting to notary service (this can take a few minutes)"
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

echo "==> Stapling ticket"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH" || true

GENERATE_APPCAST="$PROJECT_DIR/scripts/sparkle/generate_appcast"
DOCS_DIR="$PROJECT_DIR/docs"
if [[ -x "$GENERATE_APPCAST" ]]; then
    echo "==> Generating appcast"
    mkdir -p "$DOCS_DIR"
    "$GENERATE_APPCAST" "$DIST_DIR" \
        --download-url-prefix "https://github.com/jean-bovet/AudioXplorer/releases/download/v$VERSION/" \
        -o "$DOCS_DIR/appcast.xml"
    echo "Appcast written to $DOCS_DIR/appcast.xml"
    echo "Commit and push docs/appcast.xml after the GitHub release is published."
else
    echo "warning: $GENERATE_APPCAST not found, skipping appcast generation" >&2
fi

echo ""
echo "Done: $DMG_PATH"
