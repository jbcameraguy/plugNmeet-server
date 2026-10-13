#!/bin/sh
# Renders /app/config.yaml from the template using Railway variables, then starts
# the server. Only the listed variables are substituted, so any other `$` in the
# template is left alone.
set -eu

mkdir -p /app/data/log

envsubst '${PNM_SERVER_URL} ${PNM_CLIENT_VERSION} ${PNM_API_KEY} ${PNM_API_SECRET}
  ${LIVEKIT_URL} ${LIVEKIT_API_KEY} ${LIVEKIT_API_SECRET}
  ${REDIS_HOST} ${REDIS_PORT} ${REDIS_USER} ${REDIS_PASSWORD}
  ${MYSQL_HOST} ${MYSQL_PORT} ${MYSQL_USER} ${MYSQL_PASSWORD} ${MYSQL_DATABASE}
  ${NATS_URL} ${NATS_WS_URL} ${PNM_NATS_USER_SEED} ${PNM_NATS_ISSUER_SEED} ${PNM_NATS_XKEY_SEED}' \
  < /etc/plugnmeet/config.yaml.tmpl > /app/config.yaml
chmod 600 /app/config.yaml

exec plugnmeet-server
