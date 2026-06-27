#!/bin/sh
set -eu

# Fail early if the required non-secret domain is absent or malformed.
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"
case "$DOMAIN_NAME" in
    ''|*[!a-zA-Z0-9.-]*) printf 'Invalid DOMAIN_NAME.\n' >&2; exit 1 ;;
esac

TEMPLATE=/etc/nginx/templates/nginx.conf.template
CONFIG=/etc/nginx/nginx.conf
TLS_DIR=/etc/nginx/tls
CERT="$TLS_DIR/inception.crt"
KEY="$TLS_DIR/inception.key"

mkdir -p "$TLS_DIR" /run/nginx

# Generate a private self-signed certificate only inside the running container.
if [ ! -s "$CERT" ] || [ ! -s "$KEY" ]; then
    openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -sha256 \
        -days 365 \
        -keyout "$KEY" \
        -out "$CERT" \
        -subj "/C=PL/O=42/CN=$DOMAIN_NAME" \
        -addext "subjectAltName=DNS:$DOMAIN_NAME,DNS:localhost,IP:127.0.0.1"
    chmod 600 "$KEY"
    chmod 644 "$CERT"
fi

# Restrict envsubst to DOMAIN_NAME so NGINX variables such as $uri remain intact.
envsubst '${DOMAIN_NAME}' < "$TEMPLATE" > "$CONFIG"

# Refuse to start if the rendered NGINX configuration is invalid.
nginx -t

# exec makes NGINX the container's PID 1 and preserves correct signal handling.
exec "$@"
