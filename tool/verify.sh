#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tool/flutter.sh pub get
dart format --output=none --set-exit-if-changed lib packages test
bash tool/flutter.sh analyze --no-pub
bash tool/flutter.sh build apk --debug --no-pub
bash tool/flutter.sh build web --no-pub
bash tool/flutter.sh build windows --debug --no-pub
