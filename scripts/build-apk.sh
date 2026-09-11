#!/usr/bin/env bash
# Build MotoTalk Android APK (debug and/or release), ABI-split for release.
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
    echo
    echo "APK: $ROOT/app/$OUT"
    ls -lh "$OUT"
    echo
    echo "Install: adb install -r $OUT"
    ;;
  release)
    # ABI splits → app-armeabi-v7a-release.apk + app-arm64-v8a-release.apk
    flutter build apk --release --android-skip-build-dependency-validation --split-per-abi
    echo
    echo "Release APKs (per ABI):"
    ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
    echo
    echo "Install (arm64): adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
    echo "Install (armv7): adb install -r build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
    ;;
  both)
    flutter build apk --debug --android-skip-build-dependency-validation
    flutter build apk --release --android-skip-build-dependency-validation --split-per-abi
    echo "Debug:   $ROOT/app/build/app/outputs/flutter-apk/app-debug.apk"
    echo "Release:"
    ls -lh build/app/outputs/flutter-apk/*-release.apk 2>/dev/null || true
    ;;
  *)
    echo "Usage: $0 [debug|release|both]"
    exit 1
    ;;
esac
