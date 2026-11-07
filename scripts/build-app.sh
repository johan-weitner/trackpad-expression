#!/bin/zsh
# Builds build/Trackpad Expression.app — universal (Apple Silicon + Intel), release.
#
# Usage: scripts/build-app.sh [--install] [--dmg]
#   --install  copy the app to /Applications (quits a running copy first)
#   --dmg      also create build/TrackpadExpression-<version>.dmg (drag-to-Applications)
#
# Signing: uses the self-signed "Trackpad Expression Local Signing" certificate if present
# (see scripts/create-signing-cert.sh), otherwise ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=0; DMG=0
for arg in "$@"; do
    case $arg in
        --install) INSTALL=1 ;;
        --dmg) DMG=1 ;;
        *) echo "unknown option $arg"; exit 2 ;;
    esac
done

PRODUCT=TouchpadExpression
APP_NAME="Trackpad Expression"
BUNDLE_ID=com.johanweitner.TouchpadExpression
CERT_NAME="Trackpad Expression Local Signing"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" App/Info.plist)

echo "→ Building $PRODUCT $VERSION (arm64 + x86_64)"
for triple in arm64-apple-macosx14.0 x86_64-apple-macosx14.0; do
    swift build -c release --product $PRODUCT --triple $triple | grep -E "error|warning:|Compiling|complete" || true
done

APP="build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/$PRODUCT" \
    .build/arm64-apple-macosx/release/$PRODUCT \
    .build/x86_64-apple-macosx/release/$PRODUCT
cp App/Info.plist "$APP/Contents/"
cp App/AppIcon.icns "$APP/Contents/Resources/"

if security find-certificate -c "$CERT_NAME" >/dev/null 2>&1; then
    SIGN_ID="$CERT_NAME"
else
    SIGN_ID="-"
    echo "  (no \"$CERT_NAME\" certificate — signing ad-hoc; run scripts/create-signing-cert.sh)"
fi
codesign --force --sign "$SIGN_ID" --identifier $BUNDLE_ID --timestamp=none "$APP"
echo "✓ Built $APP  [$(lipo -archs "$APP/Contents/MacOS/$PRODUCT")]  signed: ${SIGN_ID/-/ad-hoc}"

if (( DMG )); then
    OUT="build/TrackpadExpression-$VERSION.dmg"
    STAGE=$(mktemp -d)
    trap 'rm -rf "$STAGE"' EXIT
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    rm -f "$OUT"
    hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null
    codesign --force --sign "$SIGN_ID" --timestamp=none "$OUT"
    echo "✓ Created $OUT"
fi

if (( INSTALL )); then
    pkill -x $PRODUCT 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    echo "✓ Installed to /Applications/$APP_NAME.app"
fi
