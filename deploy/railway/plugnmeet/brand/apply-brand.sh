#!/bin/sh
# Brands an unpacked plugNmeet client: writes assets/config.js from
# config.js.tmpl, copies the Limo Anywhere assets, and sets the page title and
# favicon. Safe to run more than once on the same directory.
# Usage: PNM_SERVER_URL=https://meet.example apply-brand.sh <client-dist-dir>
set -eu

DIST="${1:?usage: apply-brand.sh <client-dist-dir>}"
BRAND=$(cd "$(dirname "$0")" && pwd)
: "${PNM_SERVER_URL:?PNM_SERVER_URL must be set}"

[ -f "$DIST/index.html" ] || { echo "apply-brand: $DIST/index.html not found" >&2; exit 1; }
[ -d "$DIST/assets" ] || { echo "apply-brand: $DIST/assets not found" >&2; exit 1; }

envsubst '${PNM_SERVER_URL}' < "$BRAND/config.js.tmpl" > "$DIST/assets/config.js"

mkdir -p "$DIST/assets/la"
cp "$BRAND/la-room.css" "$DIST/assets/la-room.css"
cp "$BRAND/logo-light.webp" "$BRAND/logo-dark.webp" "$BRAND/favicon.png" "$DIST/assets/la/"

# The patterns match both the original and an already branded index.html.
sed -i.bak \
  -e 's#<title>[^<]*</title>#<title>Limo Anywhere Onboarding</title>#' \
  -e 's#<link rel="icon"[^>]*>#<link rel="icon" type="image/png" href="assets/la/favicon.png" />#' \
  "$DIST/index.html"
rm -f "$DIST/index.html.bak"

echo "apply-brand: branded $DIST"
