set -euo pipefail

pkill -f "flutter_tools" || true
pkill -f "dart.*flutter_tools.snapshot" || true
