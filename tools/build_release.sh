#!/usr/bin/env bash
# One-command build + verification for TCI Beach Buddies.
#
#   tools/build_release.sh path/to/grand_turk.osm      # rebuild data, then app
#   tools/build_release.sh                             # use the data already in assets/
#
# Stops at the first failing gate. Produces:
#   build/data_report.md, build/route_regression.{json,png}
#   build/app/outputs/flutter-apk/app-release.apk
#   build/app/outputs/bundle/release/app-release.aab
#   build/ios/ipa/*.ipa                     (macOS + Xcode + signing only)
set -euo pipefail
cd "$(dirname "$0")/.."

say() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }

if [[ $# -ge 1 ]]; then
  say "Gate 0: build offline data bundle from $1"
  mkdir -p data/raw && cp "$1" data/raw/ 2>/dev/null || true
  python3 -I tools/pipeline/build_bundle.py --osm "$1"
fi
[[ -f assets/manifest/manifest.json ]] || { echo "No offline bundle in assets/. Pass the OSM extract."; exit 1; }

say "Gate 1: pipeline unit tests (synthetic island)"
python3 -m unittest discover -s tools/pipeline/tests

say "Gate 2: mandatory route regression on the real bundle"
python3 -I tools/pipeline/regression.py

say "Gate 3: Flutter dependencies, static analysis, tests"
flutter --version
flutter pub get
flutter analyze
flutter test

say "Gate 4: Android release builds"
[[ -f android/key.properties ]] || echo "WARNING: android/key.properties missing - release APK is signed with DEBUG keys (QA only)."
flutter build apk --release
flutter build appbundle --release

if [[ "$(uname)" == "Darwin" ]]; then
  say "Gate 5: iOS build"
  (cd ios && pod install)
  if flutter build ipa --release; then
    echo "IPA in build/ios/ipa/"
  else
    echo "Signed IPA failed (needs an Apple Developer team in Xcode). Building unsigned for CI proof:"
    flutter build ios --release --no-codesign
  fi
else
  echo "Skipping iOS: requires macOS + Xcode."
fi

say "Done. Next: install on physical devices and run integration_test in airplane mode:"
echo "  flutter test integration_test/offline_journey_test.dart -d <device-id>"
