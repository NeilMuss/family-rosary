#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCHEME="family-rosary"
DERIVED_DATA_PATH="$ROOT_DIR/.derivedData"
PREFERRED_FALLBACK_DESTINATION="platform=iOS Simulator,name=iPhone 14"

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

  python3 -c '
import json
import re
import sys

DEVICE_PRIORITY = [
    "iPhone 14",
    "iPhone 13",
    "iPhone 12",
    "iPhone SE (3rd generation)",
]
MAJOR_PRIORITY = {16: 0, 17: 1, 15: 2}
RUNTIME_RE = re.compile(r"iOS[- ](\d+)(?:[-.](\d+))?(?:[-.](\d+))?$")

def parse_runtime(runtime_id):
    if "iOS" not in runtime_id:
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

devices_by_runtime = payload.get("devices", {})
candidates = []

for runtime_id, devices in devices_by_runtime.items():
    parsed = parse_runtime(runtime_id)
    if not parsed:
        continue

    major, minor, patch = parsed

    # Exclude iOS 18+ and future-style 26.x runtimes.
    if major >= 18 or major >= 26:
        continue

    if major not in MAJOR_PRIORITY:
        continue

    for device in devices:
        if not device.get("isAvailable", False):
            continue
        name = device.get("name")
        if name not in DEVICE_PRIORITY:
            continue

        candidates.append(
            (
                MAJOR_PRIORITY[major],              # lower is better
                DEVICE_PRIORITY.index(name),        # lower is better
                -minor,                             # higher minor preferred
                -patch,                             # higher patch preferred
                f"platform=iOS Simulator,name={name},OS={major}.{minor}",
            )
        )

if not candidates:
    print("")
else:
    candidates.sort()
    print(candidates[0][4])
' <<< "$simctl_json"
}

DESTINATION="$(pick_destination)"
if [[ -z "$DESTINATION" ]]; then
  echo "No preferred simulator found (iOS 16/17/15 + supported iPhone models)." >&2
  echo "Falling back to $PREFERRED_FALLBACK_DESTINATION" >&2
  DESTINATION="$PREFERRED_FALLBACK_DESTINATION"
fi

echo "Using destination: $DESTINATION"

CMD=(
  xcodebuild
  test
  "${CONTAINER_FLAG[@]}"
  -scheme "$SCHEME"
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -only-testing:family-rosaryTests
)

if command -v xcpretty > /dev/null 2>&1; then
  "${CMD[@]}" | xcpretty
else
  "${CMD[@]}"
fi
