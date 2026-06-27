#!/bin/sh
set -eu

# Resolve the repository root independently of the current working directory.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
ENV_FILE="$ROOT_DIR/srcs/.env"
SECRETS_DIR="$ROOT_DIR/secrets"
README_FILE="$ROOT_DIR/README.md"

fail() {
    printf 'setup: %s\n' "$1" >&2
    exit 1
}

validate_login() {
    case "$1" in
        ''|*[!a-zA-Z0-9_-]*) fail "login may contain only letters, digits, underscores, and hyphens" ;;
    esac
}

validate_wp_user() {
    case "$1" in
        ''|*[!a-zA-Z0-9_.-]*) fail "WordPress usernames may contain only letters, digits, dots, underscores, and hyphens" ;;
    esac
}

contains_admin() {
    lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
        *admin*) return 0 ;;
        *) return 1 ;;
    esac
}

# Create a local .env only once. Existing configuration is never overwritten silently.
if [ ! -f "$ENV_FILE" ]; then
    default_login=${USER:-$(id -un)}
    printf '42 login [%s]: ' "$default_login"
    IFS= read -r entered_login || true
    login=${entered_login:-$default_login}
    validate_login "$login"

    default_admin='site_owner'
    printf 'WordPress administrator username [%s]: ' "$default_admin"
    IFS= read -r entered_admin || true
    admin_user=${entered_admin:-$default_admin}
    validate_wp_user "$admin_user"
    if contains_admin "$admin_user"; then
        fail "administrator username must not contain admin or administrator"
    fi

    default_user='content_author'
    printf 'Second WordPress username [%s]: ' "$default_user"
    IFS= read -r entered_user || true
    wp_user=${entered_user:-$default_user}
    validate_wp_user "$wp_user"
    [ "$wp_user" != "$admin_user" ] || fail "the two WordPress usernames must be different"

    cat > "$ENV_FILE" <<EOF
LOGIN=$login
DOMAIN_NAME=$login.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
WP_TITLE=Inception
WP_ADMIN_USER=$admin_user
WP_ADMIN_EMAIL=$admin_user@example.com
WP_USER=$wp_user
WP_USER_EMAIL=$wp_user@example.com
WP_USER_ROLE=author
EOF
    chmod 600 "$ENV_FILE"
    printf 'Created %s\n' "$ENV_FILE"
fi

# shellcheck disable=SC1090
. "$ENV_FILE"
validate_login "$LOGIN"
validate_wp_user "$WP_ADMIN_USER"
validate_wp_user "$WP_USER"
if contains_admin "$WP_ADMIN_USER"; then
    fail "WP_ADMIN_USER must not contain admin or administrator"
fi
[ "$DOMAIN_NAME" = "$LOGIN.42.fr" ] || fail "DOMAIN_NAME must be LOGIN.42.fr"

command -v openssl >/dev/null 2>&1 || fail "openssl is required to generate secrets"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# Generate strong hexadecimal secrets without printing them to terminal output.
generate_secret() {
    target=$1
    if [ ! -s "$target" ]; then
        umask 077
        openssl rand -hex 32 > "$target"
        printf 'Created local secret: %s\n' "$target"
    fi
    chmod 600 "$target"
}

generate_secret "$SECRETS_DIR/db_root_password.txt"
generate_secret "$SECRETS_DIR/db_password.txt"
generate_secret "$SECRETS_DIR/wp_admin_password.txt"
generate_secret "$SECRETS_DIR/wp_user_password.txt"

# Create the exact host locations required by the subject.
DATA_ROOT="/home/$LOGIN/data"
if [ "$(id -u)" -eq 0 ]; then
    mkdir -p "$DATA_ROOT/mariadb" "$DATA_ROOT/wordpress"
else
    command -v sudo >/dev/null 2>&1 || fail "sudo is required to create $DATA_ROOT"
    sudo mkdir -p "$DATA_ROOT/mariadb" "$DATA_ROOT/wordpress"
fi

# Ensure the domain resolves locally inside the VM. This operation is idempotent.
if ! awk -v domain="$DOMAIN_NAME" '
    $1 == "127.0.0.1" {
        for (field = 2; field <= NF; field++) {
            if ($field == domain) {
                found = 1
            }
        }
    }
    END { exit(found ? 0 : 1) }
' /etc/hosts 2>/dev/null; then
    hosts_line="127.0.0.1 $DOMAIN_NAME"
    if [ "$(id -u)" -eq 0 ]; then
        printf '%s\n' "$hosts_line" >> /etc/hosts
    else
        printf '%s\n' "$hosts_line" | sudo tee -a /etc/hosts >/dev/null
    fi
    printf 'Added %s to /etc/hosts\n' "$DOMAIN_NAME"
fi

# Make the mandatory first README line contain the real learner login.
if [ -f "$README_FILE" ]; then
    temporary=$(mktemp)
    {
        printf '*This project has been created as part of the 42 curriculum by %s.*\n' "$LOGIN"
        tail -n +2 "$README_FILE"
    } > "$temporary"
    cat "$temporary" > "$README_FILE"
    rm -f "$temporary"
fi

printf '\nSetup complete.\n'
printf 'Domain: https://%s\n' "$DOMAIN_NAME"
printf 'Data:   %s\n' "$DATA_ROOT"
printf 'Secrets remain local in: %s\n' "$SECRETS_DIR"
