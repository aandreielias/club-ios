#!/usr/bin/env bash
# After club-server changed its API: copy its contract snapshot, then `swift test` in ClubKit checks the models.
set -euo pipefail
cd "$(dirname "$0")/.."
cp ../club-server/docs/api/openapi.json ClubKit/Contract/openapi.json
echo "openapi.json copied; run: (cd ClubKit && swift test)"
