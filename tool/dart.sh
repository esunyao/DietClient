#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
export PUB_CACHE="$project_root/.pub-cache"
export GRADLE_USER_HOME="$project_root/.gradle-cache"
export CI=true
mkdir -p "$project_root/.local/tmp"
export TMPDIR="$project_root/.local/tmp"
export TMP="$TMPDIR"
export TEMP="$TMPDIR"
dart "$@"
