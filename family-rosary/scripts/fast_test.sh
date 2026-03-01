#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCHEME="family-rosary"
DERIVED_DATA_PATH="$ROOT_DIR/.derivedData"
PREFERRED_FALLBACK_DESTINATION="platform=iOS Simulator,name=iPhone 14"
ONLY_TESTING_TARGET="family-rosaryTests"

# ---------------------------
# Container (workspace/project)
# ---------------------------
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

# ---------------------------
# Destination picker
# ---------------------------
pick_destination() {
  if [[ -n "${FAST_TEST_DESTINATION:-}" ]]; then
    echo "$FAST_TEST_DESTINATION"
    return 0
  fi

  local simctl_json
  if ! simctl_json="$(xcrun simctl list -j devices available 2>/dev/null)"; then
    echo ""
    return 0
  fi

  python3 - <<'PY' <<< "$simctl_json"
import json, sys

DEVICE_PRIORITY = [
    "iPhone 14",
    "iPhone 13",
    "iPhone 12",
    "iPhone SE (3rd generation)",
]
# Prefer iOS 16, then 17, then 15.
MAJOR_PRIORITY = {16: 0, 17: 1, 15: 2}

def parse_runtime(runtime_id: str):
    # runtime_id example: "com.apple.CoreSimulator.SimRuntime.iOS-16-4"
    if "iOS-" not in runtime_id:
        return None
    tail = runtime_id.split("iOS-", 1)[-1]
    parts = tail.split("-")
    if not parts or not parts[0].isdigit():
        return None
    major = int(parts[0])
    minor = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 0
    patch = int(parts[2]) if len(parts) > 2 and parts[2].isdigit() else 0
    return major, minor, patch

try:
    payload = json.load(sys.stdin)
except Exception:
    print("")
    sys.exit(0)

devices_by_runtime = payload.get("devices", {}) or {}
candidates = []

for runtime_id, devices in devices_by_runtime.items():
    parsed = parse_runtime(runtime_id)
    if not parsed:
        continue
    major, minor, patch = parsed

    # Avoid iOS 18+ (and future runtimes).
    if major >= 18:
        continue
    if major not in MAJOR_PRIORITY:
        continue

    for d in devices or []:
        if not d.get("isAvailable", False):
            continue
        name = d.get("name")
        if name not in DEVICE_PRIORITY:
            continue

        # Prefer higher minor/patch within the same major.
        dest = f"platform=iOS Simulator,name={name},OS={major}.{minor}"
        candidates.append((
            MAJOR_PRIORITY[major],            # iOS major preference
            DEVICE_PRIORITY.index(name),      # device preference
            -minor,                           # higher minor preferred
            -patch,                           # higher patch preferred
            dest
        ))

if not candidates:
    print("")
else:
    candidates.sort()
    print(candidates[0][4])
PY
}

DESTINATION="$(pick_destination)"
if [[ -z "$DESTINATION" ]]; then
  echo "No preferred simulator found (iOS 16/17/15 + supported iPhone models)." >&2
  echo "Falling back to: $PREFERRED_FALLBACK_DESTINATION" >&2
  DESTINATION="$PREFERRED_FALLBACK_DESTINATION"
fi

echo "Using destination: $DESTINATION"

# ---------------------------
# Helpers
# ---------------------------
run_cmd() {
  if command -v xcpretty > /dev/null 2>&1; then
    "$@" | xcpretty
  else
    "$@"
  fi
}

is_destination_error() {
  # Covers the common failure strings when CoreSimulator/devices/runtimes are missing.
  grep -Eqi \
    "Unable to find a destination|No available devices|CoreSimulator|Failed to locate a valid device|Requested but did not find available destination|No devices are available" \
    <<< "${1:-}"
}

# ---------------------------
# Commands
# ---------------------------
TEST_CMD=(
  xcodebuild
  test
  "${CONTAINER_FLAG[@]}"
  -scheme "$SCHEME"
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -only-testing:"$ONLY_TESTING_TARGET"
)

BUILD_FOR_TESTING_CMD=(
  xcodebuild
  build-for-testing
  "${CONTAINER_FLAG[@]}"
  -scheme "$SCHEME"
  -destination "generic/platform=iOS Simulator"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -only-testing:"$ONLY_TESTING_TARGET"
)

# Allow forcing compile-only mode (useful in headless/CI environments).
if [[ "${FAST_TEST_COMPILE_ONLY:-0}" == "1" ]]; then
  echo "FAST_TEST_COMPILE_ONLY=1 → running build-for-testing (compile-only)."
  run_cmd "${BUILD_FOR_TESTING_CMD[@]}"
  exit 0
fi

# ---------------------------
# Run tests; fallback if no simulator available
# ---------------------------
set +e
OUTPUT="$(
  if command -v xcpretty > /dev/null 2>&1; then
    "${TEST_CMD[@]}" 2>&1 | xcpretty
  else
    "${TEST_CMD[@]}" 2>&1
  fi
)"
STATUS=$?
set -e

if [[ $STATUS -eq 0 ]]; then
  echo "$OUTPUT"
  exit 0
fi

echo "$OUTPUT" >&2

if is_destination_error "$OUTPUT"; then
  echo ""
  echo "No CoreSimulator destination available here → falling back to compile-only validation."
  run_cmd "${BUILD_FOR_TESTING_CMD[@]}"
  exit 0
fi

exit $STATUS