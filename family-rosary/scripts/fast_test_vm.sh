#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCHEME="family-rosary"
DESTINATION="platform=iOS Simulator,name=iPhone 14,OS=16.4"
DERIVED_DATA_PATH="$ROOT_DIR/.derivedData"
ONLY_TESTING="family-rosaryTests/RecordPrayerViewModelTests"

if compgen -G "*.xcworkspace" > /dev/null; then
  WORKSPACE_PATH="$(find "$ROOT_DIR" -maxdepth 1 -name "*.xcworkspace" -print -quit)"
  CONTAINER_FLAG=(-workspace "$WORKSPACE_PATH")
elif compgen -G "*.xcodeproj" > /dev/null; then
  PROJECT_PATH="$(find "$ROOT_DIR" -maxdepth 1 -name "*.xcodeproj" -print -quit)"
  CONTAINER_FLAG=(-project "$PROJECT_PATH")
else
  echo "No .xcworkspace or .xcodeproj found in $ROOT_DIR" >&2
  exit 1
fi

CMD=(
  xcodebuild
  test
  "${CONTAINER_FLAG[@]}"
  -scheme "$SCHEME"
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -only-testing:"$ONLY_TESTING"
)

if command -v xcpretty > /dev/null 2>&1; then
  "${CMD[@]}" | xcpretty
else
  "${CMD[@]}"
fi
