#!/usr/bin/env bash
# Build MotoTalk Android APK (debug and/or release).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/app"

MODE="${1:-debug}"

echo "flutter pub get..."
flutter pub get

case "$MODE" in
  debug)
    flutter build apk --debug --android-skip-build-dependency-validation
    OUT="build/app/outputs/flutter-apk/app-debug.apk"
    ;;
  release)
    flutter build apk --release --android-skip-build-dependency-validation
    OUT="build/app/outputs/flutter-apk/app-release.apk"
    ;;
  both)
    flutter build apk --debug --android-skip-build-dependency-validation
    flutter build apk --release --android-skip-build-dependency-validation
    echo "Debug:   $ROOT/app/build/app/outputs/flutter-apk/app-debug.apk"
    echo "Release: $ROOT/app/build/app/outputs/flutter-apk/app-release.apk"
    exit 0
    ;;
  *)
    echo "Usage: $0 [debug|release|both]"
    exit 1
    ;;
esac

echo
echo "APK: $ROOT/app/$OUT"
ls -lh "$OUT"
echo
echo "Install: adb install -r $OUT"
