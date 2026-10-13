#!/bin/bash
# First-boot setup for the LiveKit media server on EC2 (Amazon Linux 2023, arm64).
# Installs Docker, reads the LiveKit API key and secret from SSM Parameter Store,
# and runs LiveKit plus Caddy (TLS for the signaling endpoint) as containers that
# restart automatically after the scheduled stop and start.
# Don't add `set -x`: it would write the API secret to the cloud-init log.
set -euo pipefail

DOMAIN="livekit.limoanywhere.training"
WEBHOOK_URL="https://meet.limoanywhere.training/webhook"
LIVEKIT_IMAGE="livekit/livekit-server:v1.13.9"
CADDY_IMAGE="caddy:2.11-alpine"

dnf install -y docker
systemctl enable --now docker

IMDS_TOKEN=$(curl -sfX PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 300')
REGION=$(curl -sf -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
API_KEY=$(aws ssm get-parameter --region "$REGION" --name /plugnmeet/livekit/api_key --query Parameter.Value --output text)
API_SECRET=$(aws ssm get-parameter --region "$REGION" --name /plugnmeet/livekit/api_secret --with-decryption --query Parameter.Value --output text)

mkdir -p /etc/livekit /etc/caddy
umask 077
cat > /etc/livekit/livekit.yaml <<EOF
port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
turn:
  enabled: true
  domain: ${DOMAIN}
  udp_port: 3478
keys:
  ${API_KEY}: ${API_SECRET}
webhook:
  api_key: ${API_KEY}
  urls:
    - ${WEBHOOK_URL}
room:
  enable_remote_unmute: true
  enabled_codecs:
    - mime: audio/opus
    - mime: audio/red
    - mime: video/vp8
    - mime: video/vp9
    - mime: video/av1
    - mime: video/h264
logging:
  level: info
EOF
umask 022

cat > /etc/caddy/Caddyfile <<EOF
${DOMAIN} {
    reverse_proxy 127.0.0.1:7880
}
EOF

docker run -d --name livekit --restart unless-stopped --network host \
  -v /etc/livekit/livekit.yaml:/etc/livekit.yaml:ro \
  "$LIVEKIT_IMAGE" --config /etc/livekit.yaml

docker run -d --name caddy --restart unless-stopped --network host \
  -v /etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
  -v caddy_data:/data -v caddy_config:/config \
  "$CADDY_IMAGE"
