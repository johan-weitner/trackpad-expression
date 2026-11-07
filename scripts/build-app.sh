#!/bin/zsh
# Builds build/Trackpad Expression.app (release, ad-hoc signed).
# Usage: scripts/build-app.sh [--install]   (--install copies it to /Applications)
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --product TouchpadExpression

APP="build/Trackpad Expression.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/TouchpadExpression "$APP/Contents/MacOS/"
cp App/Info.plist "$APP/Contents/"
codesign --force --sign - --identifier com.johanweitner.TouchpadExpression "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x TouchpadExpression 2>/dev/null || true
    rm -rf "/Applications/Trackpad Expression.app"
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/Trackpad Expression.app"
fi
