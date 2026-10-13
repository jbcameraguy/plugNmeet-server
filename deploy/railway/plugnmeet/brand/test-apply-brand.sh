#!/bin/sh
# Hermetic test for apply-brand.sh: builds a fake client tree, brands it twice,
# and checks the result. Run: sh deploy/railway/plugnmeet/brand/test-apply-brand.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

# A missing client directory must fail.
if PNM_SERVER_URL=https://meet.example.test sh "$HERE/apply-brand.sh" "$WORK/missing" 2>/dev/null; then
  fail "apply-brand.sh succeeded on a missing directory"
fi

mkdir -p "$WORK/dist/assets/imgs"
cat > "$WORK/dist/index.html" <<'EOF'
<!doctype html>
<html lang="en">
  <head>
    <link rel="icon" type="image/x-icon" href="assets/imgs/favicon.ico" />
    <title>plugNmeet</title>
    <script src="./assets/config.js"></script>
  </head>
  <body><div id="plugNmeet-app"></div></body>
</html>
EOF
echo "window.plugNmeetConfig = { serverUrl: 'http://localhost:8080' };" > "$WORK/dist/assets/config_sample.js"

PNM_SERVER_URL=https://meet.example.test sh "$HERE/apply-brand.sh" "$WORK/dist"
# Second run must be harmless.
PNM_SERVER_URL=https://meet.example.test sh "$HERE/apply-brand.sh" "$WORK/dist"

CFG="$WORK/dist/assets/config.js"
grep -q "serverUrl: 'https://meet.example.test'," "$CFG" || fail "serverUrl not set exactly"
grep -q "disableDarkMode: true" "$CFG" || fail "dark mode not disabled"
grep -q "primary_btn_bg_color: '#CC2E0F'" "$CFG" || fail "button fill is not the AA-safe orange"
grep -q "custom_css_url: '/assets/la-room.css'" "$CFG" || fail "custom CSS not wired"
grep -q "main_logo_light: '/assets/la/logo-light.webp'" "$CFG" || fail "light logo not wired"
if grep -q '\${PNM_SERVER_URL}' "$CFG"; then fail "unsubstituted variable left in config.js"; fi

for f in la-room.css la/logo-light.webp la/logo-dark.webp la/favicon.png; do
  [ -s "$WORK/dist/assets/$f" ] || fail "missing asset $f"
done

IDX="$WORK/dist/index.html"
grep -q '<title>Limo Anywhere Onboarding</title>' "$IDX" || fail "title not replaced"
grep -q 'href="assets/la/favicon.png"' "$IDX" || fail "favicon not replaced"
[ "$(grep -c '<title>' "$IDX")" = "1" ] || fail "title duplicated on rerun"

echo "PASS"
