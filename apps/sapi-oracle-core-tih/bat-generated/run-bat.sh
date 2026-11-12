#!/usr/bin/env bash
# Run the generated BAT suite against the live runtime under test.
#
# Prereqs:
#   - BAT CLI installed at $HOME/.bat/bat
#   - the app under test is running and reachable at config.url
#
# JAVA_OPTS opens java.base/java.net so PATCH works on JDK 17 (BAT overrides
# HttpURLConnection.method by reflection, which JDK 17 blocks by default).
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.bat/bat/bin:$PATH"
export JAVA_OPTS='--add-opens=java.base/java.net=ALL-UNNAMED'
bat --config=local "$@"
