# plugnmeet-server image for Railway. Build context is the repository root.
# Matches docker-build/Dockerfile, plus envsubst and a start script that writes
# config.yaml from Railway variables.

FROM mynaparrot/plugnmeet-server:base AS builder

# BuildKit sets TARGETARCH; the default covers builders that don't.
ARG TARGETARCH=amd64

WORKDIR /go/src/app

COPY go.mod go.sum ./
RUN go mod download

COPY main.go ./
COPY pkg/ pkg/
COPY version/ version/

RUN case "$TARGETARCH" in \
        "amd64") SPEECHSDK_ARCH_DIR="x64" ;; \
        "arm64") SPEECHSDK_ARCH_DIR="arm64" ;; \
        *) echo "Unsupported architecture for Speech SDK: $TARGETARCH"; exit 1 ;; \
    esac && \
    CGO_ENABLED=1 GOOS=linux GOARCH=$TARGETARCH GO111MODULE=on \
    CGO_CFLAGS="-I$SPEECHSDK_ROOT/include/c_api" \
    CGO_LDFLAGS="-L$SPEECHSDK_ROOT/lib/${SPEECHSDK_ARCH_DIR} -lMicrosoft.CognitiveServices.Speech.core" \
    go build -trimpath -ldflags '-w -s -buildid=' -a -o plugnmeet-server main.go

FROM debian:stable-slim

RUN export DEBIAN_FRONTEND=noninteractive; \
    apt-get update && \
    apt-get install --no-install-recommends -y \
    wget curl ca-certificates libreoffice img2pdf ffmpeg gettext-base \
    libasound2 libssl3 libopus0 libsoxr0 libopusfile0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /go/src/app/plugnmeet-server /usr/bin/plugnmeet-server
COPY --from=builder /usr/local/bin/mutool /usr/bin/mutool
COPY --from=builder /opt/speechsdk /opt/speechsdk

COPY docker-build/docker-entrypoint.sh /usr/local/bin/
COPY deploy/railway/plugnmeet/start.sh /usr/local/bin/pnm-start.sh
COPY deploy/railway/plugnmeet/config.yaml.tmpl /etc/plugnmeet/config.yaml.tmpl
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/pnm-start.sh

EXPOSE 8080

# docker-entrypoint.sh sets the Speech SDK library path and changes to /app.
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["pnm-start.sh"]
