#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash tool/flutter.sh pub get
bash tool/dart.sh format --output=none --set-exit-if-changed lib packages test
bash tool/flutter.sh analyze --no-pub
bash tool/dart.sh test packages/diet_oidc/test packages/diet_auth/test
bash tool/flutter.sh test --no-pub test
bash tool/flutter.sh build web --no-pub --dart-define-from-file=.env.example
bash tool/flutter.sh build windows --debug --no-pub --dart-define-from-file=.env.example
