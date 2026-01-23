set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_ID="${IRIS_IPHONE:-00008030-0009449936A0802E}"

flutter pub get

flutter run -d "$DEVICE_ID" --verbose
