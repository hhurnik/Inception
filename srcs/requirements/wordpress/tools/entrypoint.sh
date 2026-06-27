#!/bin/sh
set -eu

WP_PATH=/var/www/html
WP_SOURCE=/usr/src/wordpress
DB_SECRET=/run/secrets/db_password
ADMIN_SECRET=/run/secrets/wp_admin_password
USER_SECRET=/run/secrets/wp_user_password

fail() {
    printf 'wordpress-entrypoint: %s\n' "$1" >&2
    exit 1
}

require_env() {
    name=$1
    eval "value=\${$name:-}"
    [ -n "$value" ] || fail "$name is required"
}

validate_identifier() {
    case "$1" in
        ''|*[!a-zA-Z0-9_]*) fail "invalid database identifier: $1" ;;
    esac
}

validate_wp_user() {
    case "$1" in
        ''|*[!a-zA-Z0-9_.-]*) fail "invalid WordPress username: $1" ;;
    esac
}

read_hex_secret() {
    file=$1
    [ -r "$file" ] || fail "missing secret file: $file"
    value=$(tr -d '\r\n' < "$file")
    case "$value" in
        ''|*[!a-fA-F0-9]*) fail "secret must be hexadecimal: $file" ;;
    esac
    [ "${#value}" -ge 32 ] || fail "secret is too short: $file"
    printf '%s' "$value"
}

for variable in DOMAIN_NAME MYSQL_DATABASE MYSQL_USER WP_TITLE WP_ADMIN_USER WP_ADMIN_EMAIL WP_USER WP_USER_EMAIL WP_USER_ROLE; do
    require_env "$variable"
done
validate_identifier "$MYSQL_DATABASE"
validate_identifier "$MYSQL_USER"
validate_wp_user "$WP_ADMIN_USER"
validate_wp_user "$WP_USER"
[ "$WP_ADMIN_USER" != "$WP_USER" ] || fail "WordPress usernames must be different"

lower_admin=$(printf '%s' "$WP_ADMIN_USER" | tr '[:upper:]' '[:lower:]')
case "$lower_admin" in
    *admin*) fail "administrator username must not contain admin or administrator" ;;
esac

case "$DOMAIN_NAME" in
    ''|*[!a-zA-Z0-9.-]*) fail "invalid DOMAIN_NAME" ;;
esac
case "$WP_ADMIN_EMAIL" in *'@'*'.'*) : ;; *) fail "invalid WP_ADMIN_EMAIL" ;; esac
case "$WP_USER_EMAIL" in *'@'*'.'*) : ;; *) fail "invalid WP_USER_EMAIL" ;; esac
case "$WP_USER_ROLE" in subscriber|contributor|author|editor) : ;; *) fail "unsafe WP_USER_ROLE" ;; esac

# Validate secret files without exporting their values into the PHP-FPM environment.
DB_PASSWORD=$(read_hex_secret "$DB_SECRET")
RUNTIME_DB_SECRET=/run/wordpress-db-password
install -o www-data -g www-data -m 0400 "$DB_SECRET" "$RUNTIME_DB_SECRET"
read_hex_secret "$ADMIN_SECRET" >/dev/null
read_hex_secret "$USER_SECRET" >/dev/null

mkdir -p /run/php "$WP_PATH"

# Populate an empty persistent volume from the versioned core stored in the image.
if [ ! -f "$WP_PATH/wp-includes/version.php" ]; then
    printf 'Copying WordPress core into the persistent volume...\n'
    cp -a "$WP_SOURCE/." "$WP_PATH/"
fi
chown -R www-data:www-data "$WP_PATH" /run/php

# Generate wp-config.php without embedding the real database password.
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    wp config create \
        --allow-root \
        --path="$WP_PATH" \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass=temporary-placeholder \
        --dbhost=mariadb:3306 \
        --dbcharset=utf8mb4 \
        --skip-check \
        --skip-salts

    # Generate salts locally so first startup does not depend on an external salt API.
    for key in AUTH_KEY SECURE_AUTH_KEY LOGGED_IN_KEY NONCE_KEY AUTH_SALT SECURE_AUTH_SALT LOGGED_IN_SALT NONCE_SALT; do
        wp config set "$key" "$(openssl rand -base64 48)" --allow-root --path="$WP_PATH"
    done
fi

# Reconcile non-secret settings on every start and keep DB_PASSWORD as a runtime file expression.
wp config set DB_NAME "$MYSQL_DATABASE" --allow-root --path="$WP_PATH"
wp config set DB_USER "$MYSQL_USER" --allow-root --path="$WP_PATH"
wp config set DB_HOST 'mariadb:3306' --allow-root --path="$WP_PATH"
wp config set DB_CHARSET 'utf8mb4' --allow-root --path="$WP_PATH"
wp config set DB_PASSWORD "trim(file_get_contents('/run/wordpress-db-password'))" --raw --allow-root --path="$WP_PATH"
wp config set WP_HOME "https://$DOMAIN_NAME" --allow-root --path="$WP_PATH"
wp config set WP_SITEURL "https://$DOMAIN_NAME" --allow-root --path="$WP_PATH"
wp config set FORCE_SSL_ADMIN true --raw --allow-root --path="$WP_PATH"
wp config set DISALLOW_FILE_EDIT true --raw --allow-root --path="$WP_PATH"
wp config set WP_ENVIRONMENT_TYPE 'local' --allow-root --path="$WP_PATH"
wp config set WP_DEBUG false --raw --allow-root --path="$WP_PATH"
chmod 0640 "$WP_PATH/wp-config.php"
chown www-data:www-data "$WP_PATH/wp-config.php"

# Use a temporary MariaDB option file so the password does not appear in process arguments.
client_config=$(mktemp)
cleanup_client_config() { rm -f "$client_config"; }
trap cleanup_client_config EXIT HUP INT TERM
chmod 600 "$client_config"
cat > "$client_config" <<EOF
[client]
user=$MYSQL_USER
password=$DB_PASSWORD
host=mariadb
port=3306
protocol=tcp
EOF
unset DB_PASSWORD

ready=0
for attempt in $(seq 1 60); do
    if mariadb-admin --defaults-extra-file="$client_config" ping --silent >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
[ "$ready" -eq 1 ] || fail "MariaDB did not become ready"
cleanup_client_config
trap - EXIT HUP INT TERM

# The WordPress installation is idempotent because WP-CLI checks database tables first.
if ! wp core is-installed --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
    wp core install \
        --allow-root \
        --path="$WP_PATH" \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --prompt=admin_password < "$ADMIN_SECRET" >/dev/null 2>&1
fi

# Create exactly the required second user if it does not already exist.
if ! wp user exists "$WP_USER" --allow-root --path="$WP_PATH" >/dev/null 2>&1; then
    wp user create "$WP_USER" "$WP_USER_EMAIL" \
        --allow-root \
        --path="$WP_PATH" \
        --role="$WP_USER_ROLE" \
        --prompt=user_pass < "$USER_SECRET" >/dev/null 2>&1
else
    wp user update "$WP_USER" --allow-root --path="$WP_PATH" --role="$WP_USER_ROLE" >/dev/null
fi

chown -R www-data:www-data "$WP_PATH"

# Replace the shell with foreground PHP-FPM so it receives container signals directly.
exec "$@"
