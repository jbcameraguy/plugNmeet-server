#!/bin/sh
# Downloads and brands the plugNmeet web client, renders /app/config.yaml from
# the template using Railway variables, then starts the server. Only the listed
# variables are substituted, so any other `$` in the template is left alone.
# Any failure stops the container rather than serving an unbranded client.
set -eu

ETC=/etc/plugnmeet
mkdir -p /app/data/log

: "${PNM_SERVER_URL:?PNM_SERVER_URL must be set}"
: "${PNM_CLIENT_VERSION:?PNM_CLIENT_VERSION must name a client release tag}"
. "$ETC/webhook-defaults.sh"

TMP=$(mktemp -d)
curl -fsSL -o "$TMP/client.zip" \
  "https://github.com/mynaparrot/plugNmeet-client/releases/download/${PNM_CLIENT_VERSION}/client.zip"
unzip -q "$TMP/client.zip" -d "$TMP"
[ -d "$TMP/client/dist" ] || { echo "start: client/dist missing from client.zip" >&2; exit 1; }
rm -rf /app/client/dist
mkdir -p /app/client
mv "$TMP/client/dist" /app/client/dist
rm -rf "$TMP"

sh /usr/local/share/plugnmeet-brand/apply-brand.sh /app/client/dist

envsubst "$(cat "$ETC/template-vars.txt")" < "$ETC/config.yaml.tmpl" > /app/config.yaml
chmod 600 /app/config.yaml

exec plugnmeet-server
