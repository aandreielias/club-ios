#!/usr/bin/env bash
# After club-server changed its API: copy its contract snapshot and error codes, export the client's German error texts,
# then `swift test` in ClubKit checks the models and that every code has a text.
set -euo pipefail
cd "$(dirname "$0")/.."
cp ../club-server/docs/api/openapi.json ../club-server/docs/api/error-codes.json ClubKit/Contract/
node scripts/error-texts.mjs
echo "copied; run: (cd ClubKit && swift test)"
