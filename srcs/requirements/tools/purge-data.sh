#!/bin/sh
set -eu

# [EN] This is deliberately separate from normal cleanup because it permanently deletes data.
# [PL] To jest celowo oddzielone od zwykłego czyszczenia, ponieważ trwale usuwa dane.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
ENV_FILE="$ROOT_DIR/srcs/.env"
[ -f "$ENV_FILE" ] || { printf 'Missing srcs/.env\n' >&2; exit 1; }
# shellcheck disable=SC1090
. "$ENV_FILE"

case "$LOGIN" in
    ''|*[!a-zA-Z0-9_-]*) printf 'Unsafe LOGIN value.\n' >&2; exit 1 ;;
esac
DATA_ROOT="/home/$LOGIN/data"

printf 'This will permanently delete:\n  %s/mariadb\n  %s/wordpress\n' "$DATA_ROOT" "$DATA_ROOT"
printf 'Type DELETE to continue: '
IFS= read -r answer
[ "$answer" = DELETE ] || { printf 'Cancelled.\n'; exit 0; }

docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/srcs/docker-compose.yml" down --remove-orphans --volumes --rmi local || true

if [ "$(id -u)" -eq 0 ]; then
    rm -rf -- "$DATA_ROOT/mariadb" "$DATA_ROOT/wordpress"
    mkdir -p "$DATA_ROOT/mariadb" "$DATA_ROOT/wordpress"
else
    sudo rm -rf -- "$DATA_ROOT/mariadb" "$DATA_ROOT/wordpress"
    sudo mkdir -p "$DATA_ROOT/mariadb" "$DATA_ROOT/wordpress"
fi
printf 'Persistent data has been reset. Local secret files were preserved.\n'
