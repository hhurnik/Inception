#!/bin/sh
set -eu

# Static validation works even before Docker is installed.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
ERRORS=0

pass() { printf '[OK] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1" >&2; ERRORS=$((ERRORS + 1)); }

required_files='
Makefile
README.md
USER_DOC.md
DEV_DOC.md
srcs/docker-compose.yml
srcs/.env.example
srcs/requirements/nginx/Dockerfile
srcs/requirements/nginx/conf/nginx.conf.template
srcs/requirements/nginx/tools/entrypoint.sh
srcs/requirements/wordpress/Dockerfile
srcs/requirements/wordpress/conf/php-fpm.conf
srcs/requirements/wordpress/conf/www.conf
srcs/requirements/wordpress/conf/wordpress.ini
srcs/requirements/wordpress/tools/entrypoint.sh
srcs/requirements/wordpress/tools/healthcheck.sh
srcs/requirements/mariadb/Dockerfile
srcs/requirements/mariadb/conf/99-inception.cnf
srcs/requirements/mariadb/tools/entrypoint.sh
srcs/requirements/mariadb/tools/healthcheck.sh'

for relative in $required_files; do
    if [ -f "$ROOT_DIR/$relative" ]; then
        pass "exists: $relative"
    else
        fail "missing: $relative"
    fi
done

# Shell syntax is checked without executing any service script.
for script in \
    "$ROOT_DIR"/srcs/requirements/*/tools/*.sh \
    "$ROOT_DIR"/srcs/requirements/tools/*.sh; do
    [ -f "$script" ] || continue
    if sh -n "$script"; then
        pass "shell syntax: ${script#"$ROOT_DIR/"}"
    else
        fail "shell syntax: ${script#"$ROOT_DIR/"}"
    fi
done

# No Dockerfile may use the prohibited latest tag.
if grep -RniE '^[[:space:]]*FROM[[:space:]]+[^#[:space:]]*:latest([[:space:]]|$)' "$ROOT_DIR/srcs/requirements" --include='Dockerfile'; then
    fail "a Dockerfile uses :latest"
else
    pass "no Dockerfile uses :latest"
fi

# Check specifically the executable entrypoints for forbidden keepalive hacks.
entrypoints=$(find "$ROOT_DIR/srcs/requirements" -path '*/tools/entrypoint.sh' -type f)
if grep -nE '(^|[;&|[:space:]])(tail[[:space:]]+-f|sleep[[:space:]]+infinity|while[[:space:]]+true)' $entrypoints; then
    fail "a prohibited keepalive command appears in an entrypoint"
else
    pass "no prohibited keepalive command in service entrypoints"
fi

if grep -nE '^[[:space:]]*(network_mode:[[:space:]]*host|links:)' "$ROOT_DIR/srcs/docker-compose.yml"; then
    fail "host networking or links is configured"
else
    pass "no host networking or links"
fi

# Verify that only NGINX has a ports section in the intended Compose file.
ports_count=$(grep -c '^[[:space:]]*ports:' "$ROOT_DIR/srcs/docker-compose.yml" || true)
[ "$ports_count" -eq 1 ] && pass "exactly one ports section" || fail "expected exactly one ports section"

grep -q '"443:443"' "$ROOT_DIR/srcs/docker-compose.yml" && pass "host port 443 is published" || fail "443:443 mapping is missing"

# Validate local configuration when setup has already created it.
if [ -f "$ROOT_DIR/srcs/.env" ]; then
    # shellcheck disable=SC1090
    . "$ROOT_DIR/srcs/.env"
    lower_admin=$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')
    case "$lower_admin" in
        *admin*) fail "WP_ADMIN_USER contains admin" ;;
        *) pass "WP_ADMIN_USER does not contain admin" ;;
    esac
    [ "$DOMAIN_NAME" = "$LOGIN.42.fr" ] && pass "domain matches login.42.fr" || fail "domain does not match login.42.fr"
else
    printf '[SKIP] srcs/.env does not exist; run make setup\n'
fi

# Git must not track the real environment file or secret values.
if command -v git >/dev/null 2>&1 && git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    tracked=$(git -C "$ROOT_DIR" ls-files 'srcs/.env' 'secrets/*.txt')
    if [ -n "$tracked" ]; then
        printf '%s\n' "$tracked" >&2
        fail "sensitive local files are tracked by Git"
    else
        pass "Git does not track .env or secret text files"
    fi
fi

# Compose performs the authoritative schema/interpolation check when available.
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 && [ -f "$ROOT_DIR/srcs/.env" ]; then
    if docker compose --env-file "$ROOT_DIR/srcs/.env" -f "$ROOT_DIR/srcs/docker-compose.yml" config --quiet; then
        pass "docker compose config"
    else
        fail "docker compose config"
    fi
else
    printf '[SKIP] Docker Compose is unavailable; runtime validation must be done on the VM\n'
fi

if [ "$ERRORS" -ne 0 ]; then
    printf '\nStatic validation failed with %s error(s).\n' "$ERRORS" >&2
    exit 1
fi
printf '\nStatic validation passed.\n'
