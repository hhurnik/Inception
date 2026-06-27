#!/bin/sh
set -eu

# [EN] This script tests the running stack from the host VM.
# [PL] Ten skrypt testuje uruchomiony stack z poziomu hosta VM.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
ENV_FILE="$ROOT_DIR/srcs/.env"
COMPOSE_FILE="$ROOT_DIR/srcs/docker-compose.yml"

[ -f "$ENV_FILE" ] || { printf 'Run make setup first.\n' >&2; exit 1; }
# shellcheck disable=SC1090
. "$ENV_FILE"
COMPOSE="docker compose --env-file $ENV_FILE -f $COMPOSE_FILE"
ERRORS=0

ok() { printf '[OK] %s\n' "$1"; }
bad() { printf '[FAIL] %s\n' "$1" >&2; ERRORS=$((ERRORS + 1)); }

command -v docker >/dev/null 2>&1 || { printf 'Docker is required.\n' >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { printf 'curl is required.\n' >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { printf 'openssl is required.\n' >&2; exit 1; }

$COMPOSE ps

for service in mariadb wordpress nginx; do
    running=$(docker inspect --format '{{.State.Running}}' "$service" 2>/dev/null || printf false)
    [ "$running" = true ] && ok "$service is running" || bad "$service is not running"
    health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$service" 2>/dev/null || printf missing)
    [ "$health" = healthy ] && ok "$service is healthy" || bad "$service health is $health"
done

# [EN] Only NGINX may publish a host port.
# [PL] Tylko NGINX może publikować port hosta.
for service in mariadb wordpress; do
    published=$(docker port "$service" 2>/dev/null || true)
    [ -z "$published" ] && ok "$service publishes no host port" || bad "$service unexpectedly publishes: $published"
done
nginx_port=$(docker port nginx 443/tcp 2>/dev/null || true)
printf '%s' "$nginx_port" | grep -q ':443$' && ok "NGINX publishes 443" || bad "NGINX 443 mapping is missing"

# [EN] Resolve the local domain explicitly so the test is independent of DNS caching.
# [PL] Rozwiąż lokalną domenę jawnie, aby test nie zależał od cache DNS.
if curl --fail --silent --show-error --insecure --resolve "$DOMAIN_NAME:443:127.0.0.1" "https://$DOMAIN_NAME/healthz" | grep -qx 'ok'; then
    ok "HTTPS health endpoint"
else
    bad "HTTPS health endpoint"
fi

if openssl s_client -connect 127.0.0.1:443 -servername "$DOMAIN_NAME" -tls1_2 </dev/null 2>/dev/null | grep -q 'Protocol  : TLSv1.2\|Protocol version: TLSv1.2'; then
    ok "TLS 1.2 accepted"
else
    bad "TLS 1.2 failed"
fi

if openssl s_client -connect 127.0.0.1:443 -servername "$DOMAIN_NAME" -tls1_3 </dev/null 2>/dev/null | grep -q 'TLSv1.3'; then
    ok "TLS 1.3 accepted"
else
    bad "TLS 1.3 failed"
fi

if openssl s_client -connect 127.0.0.1:443 -servername "$DOMAIN_NAME" -tls1_1 </dev/null >/dev/null 2>&1; then
    bad "TLS 1.1 was unexpectedly accepted"
else
    ok "TLS 1.1 rejected"
fi

for volume in mariadb_data wordpress_data; do
    docker volume inspect "$volume" >/dev/null 2>&1 && ok "named volume exists: $volume" || bad "missing named volume: $volume"
done

docker network inspect inception >/dev/null 2>&1 && ok "custom network exists" || bad "custom network missing"

user_count=$(docker exec wordpress wp user list --allow-root --path=/var/www/html --format=count 2>/dev/null || printf 0)
[ "$user_count" -ge 2 ] 2>/dev/null && ok "WordPress has at least two users" || bad "WordPress user count is $user_count"

admin_role=$(docker exec wordpress wp user get "$WP_ADMIN_USER" --allow-root --path=/var/www/html --field=roles 2>/dev/null || true)
printf '%s' "$admin_role" | grep -q administrator && ok "configured owner is an administrator" || bad "configured owner lacks administrator role"

lower_admin=$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')
case "$lower_admin" in
    *admin*) bad "administrator login contains admin" ;;
    *) ok "administrator login naming rule" ;;
esac

if [ "$ERRORS" -ne 0 ]; then
    printf '\nRuntime verification failed with %s error(s).\n' "$ERRORS" >&2
    exit 1
fi
printf '\nRuntime verification passed.\n'
