#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PUB_CACHE="$PWD/.pub-cache"
export GRADLE_USER_HOME="$PWD/.gradle-cache"
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
mkdir -p .local/tmp
export TMPDIR="$PWD/.local/tmp"
export TMP="$TMPDIR"
export TEMP="$TMPDIR"
flutter --no-version-check "$@"
