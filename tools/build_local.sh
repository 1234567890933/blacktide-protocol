#!/usr/bin/env bash
# Local arm64 Android build. Mirrors .github/workflows/android.yml so the same
# command works on a laptop and in CI.
#
# Requirements: Godot 4.3 export templates, JDK 17, Android SDK (platform 34,
# build-tools 34.0.0), and an editor settings file pointing at both.
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"
OUT_DIR="${OUT_DIR:-build}"

echo "== Godot: $(${GODOT_BIN} --version)"

echo "== Importing project"
"${GODOT_BIN}" --headless --path . --import

echo "== Validating scripts"
"${GODOT_BIN}" --headless --path . --script tools/validate.gd

echo "== Exporting debug APK (arm64-v8a only)"
mkdir -p "${OUT_DIR}"
"${GODOT_BIN}" --headless --path . --export-debug "Android" "${OUT_DIR}/blacktide.apk"

echo "== Checking architectures"
unzip -l "${OUT_DIR}/blacktide.apk" | grep -E "lib/" || true
if unzip -l "${OUT_DIR}/blacktide.apk" | grep -q "lib/armeabi-v7a/"; then
  echo "ERROR: 32-bit libraries present" >&2
  exit 1
fi

ls -lh "${OUT_DIR}/blacktide.apk"
echo "== Install with: adb install -r ${OUT_DIR}/blacktide.apk"
