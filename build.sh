#!/bin/zsh
# Builds Cloak.app from source.  Usage:  ./build.sh           build and open
#                                         ./build.sh install   build, copy to /Applications, open
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift is not installed. Run:  xcode-select --install   then run this script again."
  exit 1
fi

echo "==> Compiling (release)"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Cloak"
if [[ ! -x "$BIN" ]]; then
  BIN="$(find .build -type f -name Cloak -perm -u+x -not -path '*.dSYM*' 2>/dev/null | head -n 1 || true)"
fi
if [[ -z "$BIN" || ! -x "$BIN" ]]; then
  echo "error: could not find the built Cloak binary"
  exit 1
fi

APP="Cloak.app"
echo "==> Assembling $APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -f "$BIN" "$APP/Contents/MacOS/Cloak"

echo "==> Making the icon"
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z $double $double Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Cloak</string>
  <key>CFBundleDisplayName</key><string>Cloak</string>
  <key>CFBundleIdentifier</key><string>io.github.diamond9k.cloak</string>
  <key>CFBundleExecutable</key><string>Cloak</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Signing (ad hoc, for this Mac)"
codesign --force --sign - "$APP" >/dev/null

if [[ "${1:-}" == "install" ]]; then
  echo "==> Copying to /Applications"
  ditto "$APP" "/Applications/$APP"
  open "/Applications/$APP"
else
  open "$APP"
fi
echo "==> Done"
