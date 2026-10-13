# Sourced by start.sh and the template test. An empty YAML value for
# webhook_conf.enable fails config parsing, so the flag always has a value.
case "${PNM_WEBHOOK_ENABLED:-false}" in
  true) PNM_WEBHOOK_ENABLED=true ;;
  *) PNM_WEBHOOK_ENABLED=false ;;
esac
PNM_WEBHOOK_URL="${PNM_WEBHOOK_URL:-}"
export PNM_WEBHOOK_ENABLED PNM_WEBHOOK_URL
