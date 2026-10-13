#!/bin/sh
# Renders config.yaml.tmpl the way start.sh does and checks the keys this fork
# changes. Run: sh deploy/railway/plugnmeet/test-config-template.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
fail() { echo "FAIL: $1"; exit 1; }

render() {
  # Same variable list as start.sh.
  envsubst "$(cat "$HERE/template-vars.txt")" < "$HERE/config.yaml.tmpl"
}

export PNM_SERVER_URL=https://meet.example.test PNM_CLIENT_VERSION=v2.5.3
unset PNM_WEBHOOK_ENABLED PNM_WEBHOOK_URL || true
. "$HERE/webhook-defaults.sh"
OUT=$(render)

echo "$OUT" | grep -q "text: 'Limo Anywhere Onboarding'" || fail "copyright text not set"
echo "$OUT" | grep -A1 'auto_client_download:' | grep -q 'enabled: false' || fail "auto download still on"
echo "$OUT" | grep -A1 'webhook_conf:' | grep -q 'enable: false' || fail "webhook default is not false"
if echo "$OUT" | grep -A1 'webhook_conf:' | grep -q 'enable: $'; then fail "webhook enable rendered empty"; fi

export PNM_WEBHOOK_ENABLED=true PNM_WEBHOOK_URL=https://onboarding.example.test/api/webhook/plugnmeet
OUT=$(render)
echo "$OUT" | grep -A1 'webhook_conf:' | grep -q 'enable: true' || fail "webhook enable not passed through"
echo "$OUT" | grep -q 'url: "https://onboarding.example.test/api/webhook/plugnmeet"' || fail "webhook url not passed through"

echo "PASS"
