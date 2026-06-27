#!/bin/sh
set -eu

# [EN] A temporary option file prevents the database password from appearing in process arguments.
# [PL] Tymczasowy plik opcji zapobiega pojawieniu się hasła bazy w argumentach procesu.
: "${MYSQL_USER:?MYSQL_USER is required}"
SECRET=/run/secrets/db_password
[ -r "$SECRET" ] || exit 1
password=$(tr -d '\r\n' < "$SECRET")
temporary=$(mktemp)
trap 'rm -f "$temporary"' EXIT HUP INT TERM
chmod 600 "$temporary"
cat > "$temporary" <<EOF
[client]
user=$MYSQL_USER
password=$password
host=127.0.0.1
port=3306
protocol=tcp
EOF
mariadb-admin --defaults-extra-file="$temporary" ping --silent >/dev/null
