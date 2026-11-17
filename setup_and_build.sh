#!/usr/bin/env bash
# One-step setup + APK build (Linux / macOS). Needs Flutter + Android SDK installed.
set -euo pipefail
cd "$(dirname "$0")"

command -v flutter >/dev/null 2>&1 || {
  echo "ERROR: 'flutter' is not on PATH. Install Flutter or add it to PATH first." >&2
  exit 1
}

# 1) create the Android project files only when they are missing
#    (keeps lib/, pubspec.yaml, assets/ and avoids touching a configured android/)
if [ ! -f android/app/build.gradle ] && [ ! -f android/app/build.gradle.kts ]; then
  echo "==> Creating Android project files"
  flutter create --platforms=android --project-name anicare --org com.anicare .
else
  echo "==> Android project already configured, skipping flutter create"
fi
rm -f test/widget_test.dart

# 2) launcher icon (white square with the AniCare logo)
echo "==> Copying launcher icons"
for d in tool/icons/mipmap-*; do
  n=$(basename "$d"); mkdir -p "android/app/src/main/res/$n"
  cp "$d/ic_launcher.png" "android/app/src/main/res/$n/ic_launcher.png"
done

# 3) app name, INTERNET + notification permissions, back-button support, notification desugaring
echo "==> Patching Android manifest/build files"
python3 tool/patch_android.py

# 4) clean, resolve dependencies, build (set SKIP_CLEAN=1 to keep the previous build cache)
if [ "${SKIP_CLEAN:-0}" != "1" ]; then
  echo "==> flutter clean"
  flutter clean
fi
echo "==> flutter pub get"
flutter pub get

echo "==> flutter build apk --release"
flutter build apk --release

# 5) name the APK after the app version in pubspec.yaml (e.g. AniCare-1.3.0.apk)
VER=$(grep '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')
OUT="AniCare-$VER.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT"

echo
echo "DONE -> $(pwd)/$OUT"
echo "Install on a connected device with: adb install -r \"$OUT\""
