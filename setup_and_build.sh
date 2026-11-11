#!/usr/bin/env bash
# One-step setup + APK build (Linux / macOS). Needs Flutter + Android SDK installed.
set -e
cd "$(dirname "$0")"

# 1) create the Android project files (keeps lib/, pubspec.yaml, assets/)
flutter create --platforms=android --project-name anicare --org com.anicare .
rm -f test/widget_test.dart

# 2) app name + launcher icon (white square with the AniCare logo)
M=android/app/src/main/AndroidManifest.xml
sed -i 's/android:label="[^"]*"/android:label="AniCare"/' "$M"
for d in tool/icons/mipmap-*; do
  n=$(basename "$d"); mkdir -p "android/app/src/main/res/$n"
  cp "$d/ic_launcher.png" "android/app/src/main/res/$n/ic_launcher.png"
done

# 3) make sure the phone's back button is handled by the app (Android 13+)
grep -q enableOnBackInvokedCallback "$M" || sed -i '0,/<application/s//<application android:enableOnBackInvokedCallback="true"/' "$M"

# 4) build
flutter pub get
flutter build apk --release

# 5) name the APK after the app version in pubspec.yaml (e.g. AniCare-5.0.0.apk)
VER=$(grep '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')
OUT="AniCare-$VER.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$OUT"
echo
echo "DONE -> $(pwd)/$OUT"
