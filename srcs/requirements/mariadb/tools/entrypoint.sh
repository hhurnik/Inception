#!/bin/sh
set -eu

DATADIR=/var/lib/mysql
SOCKET=/run/mysqld/mysqld.sock
PIDFILE=/run/mysqld/mysqld.pid
ROOT_SECRET=/run/secrets/db_root_password
DB_SECRET=/run/secrets/db_password

fail() {
    printf 'mariadb-entrypoint: %s\n' "$1" >&2
    exit 1
}

# [EN] Database identifiers are validated before being inserted into SQL statements.
# [PL] Identyfikatory bazy są sprawdzane przed wstawieniem do instrukcji SQL.
validate_identifier() {
    case "$1" in
        ''|*[!a-zA-Z0-9_]*) fail "invalid SQL identifier: $1" ;;
    esac
}

# [EN] Setup generates hexadecimal secrets, which avoid SQL quoting ambiguity.
# [PL] Setup generuje sekrety szesnastkowe, które unikają niejednoznaczności cytowania SQL.
read_hex_secret() {
    file=$1
    [ -r "$file" ] || fail "missing secret file: $file"
    value=$(tr -d '\r\n' < "$file")
    case "$value" in
        ''|*[!a-fA-F0-9]*) fail "secret must be a non-empty hexadecimal string: $file" ;;
    esac
    [ "${#value}" -ge 32 ] || fail "secret is too short: $file"
    printf '%s' "$value"
}

: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
: "${MYSQL_USER:?MYSQL_USER is required}"
validate_identifier "$MYSQL_DATABASE"
validate_identifier "$MYSQL_USER"
[ "$MYSQL_USER" != root ] || fail "MYSQL_USER must not be root"

ROOT_PASSWORD=$(read_hex_secret "$ROOT_SECRET")
DB_PASSWORD=$(read_hex_secret "$DB_SECRET")

mkdir -p /run/mysqld "$DATADIR"
chown -R mysql:mysql /run/mysqld "$DATADIR"
chmod 0750 "$DATADIR"

# [EN] Initialize exactly once. The mysql system directory is the persistence marker.
# [PL] Inicjalizuj dokładnie raz. Katalog systemowy mysql jest znacznikiem trwałości.
if [ ! -d "$DATADIR/mysql" ]; then
    printf 'Initializing MariaDB data directory...\n'
    mariadb-install-db \
        --user=mysql \
        --datadir="$DATADIR" \
        --auth-root-authentication-method=normal \
        --skip-test-db >/dev/null

    # [EN] The temporary server accepts local socket connections only during initialization.
    # [PL] Tymczasowy serwer przyjmuje podczas inicjalizacji wyłącznie lokalne połączenia socket.
    mariadbd \
        --user=mysql \
        --datadir="$DATADIR" \
        --socket="$SOCKET" \
        --pid-file="$PIDFILE" \
        --skip-networking &
    temporary_pid=$!

    cleanup_temporary() {
        if kill -0 "$temporary_pid" 2>/dev/null; then
            kill -TERM "$temporary_pid" 2>/dev/null || true
            wait "$temporary_pid" 2>/dev/null || true
        fi
    }
    trap cleanup_temporary EXIT HUP INT TERM

    ready=0
    for attempt in $(seq 1 60); do
        if mariadb-admin --protocol=socket --socket="$SOCKET" -uroot ping --silent >/dev/null 2>&1; then
            ready=1
            break
        fi
        kill -0 "$temporary_pid" 2>/dev/null || fail "temporary MariaDB process exited"
        sleep 1
    done
    [ "$ready" -eq 1 ] || fail "temporary MariaDB did not become ready"

    # [EN] Passwords arrive through standard input, not Dockerfile, Compose, or command arguments.
    # [PL] Hasła trafiają przez standardowe wejście, a nie Dockerfile, Compose ani argumenty polecenia.
    mariadb --protocol=socket --socket="$SOCKET" -uroot <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_PASSWORD';
DROP USER IF EXISTS 'root'@'127.0.0.1';
DROP USER IF EXISTS 'root'@'::1';
DROP USER IF EXISTS 'root'@'${HOSTNAME}';
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'${HOSTNAME}';
DROP DATABASE IF EXISTS test;
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$MYSQL_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';
FLUSH PRIVILEGES;
SQL

    # [EN] Stop the temporary process cleanly before starting the final PID 1 server.
    # [PL] Zatrzymaj czysto proces tymczasowy przed uruchomieniem docelowego serwera PID 1.
    kill -TERM "$temporary_pid"
    wait "$temporary_pid"
    trap - EXIT HUP INT TERM
    printf 'MariaDB initialization complete.\n'
fi

# [EN] Replace the shell with the real database server; no keepalive loop is required.
# [PL] Zastąp shell prawdziwym serwerem bazy; żadna pętla podtrzymująca nie jest potrzebna.
exec "$@" --user=mysql --datadir="$DATADIR" --socket="$SOCKET" --pid-file="$PIDFILE"
