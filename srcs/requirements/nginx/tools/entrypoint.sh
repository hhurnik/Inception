#!/bin/sh
set -eu

# [EN] Fail early if the required non-secret domain is absent or malformed.
# [PL] Zakończ wcześnie, jeśli wymagana niejawna domena jest nieobecna albo błędna.
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

# [EN] Generate a private self-signed certificate only inside the running container.
# [PL] Generuj prywatny certyfikat samopodpisany wyłącznie wewnątrz uruchomionego kontenera.
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

# [EN] Restrict envsubst to DOMAIN_NAME so NGINX variables such as $uri remain intact.
# [PL] Ogranicz envsubst do DOMAIN_NAME, aby zmienne NGINX-a, takie jak $uri, pozostały nienaruszone.
envsubst '${DOMAIN_NAME}' < "$TEMPLATE" > "$CONFIG"

# [EN] Refuse to start if the rendered NGINX configuration is invalid.
# [PL] Odmów startu, jeśli wyrenderowana konfiguracja NGINX-a jest nieprawidłowa.
nginx -t

# [EN] exec makes NGINX the container's PID 1 and preserves correct signal handling.
# [PL] exec czyni NGINX procesem PID 1 kontenera i zachowuje poprawną obsługę sygnałów.
exec "$@"
