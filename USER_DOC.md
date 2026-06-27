# User Documentation

## Services provided

The stack provides a local WordPress website over HTTPS:

- NGINX receives browser requests on port `443`.
- WordPress and PHP-FPM generate the website and administration panel.
- MariaDB stores posts, settings, and user records.

The internal MariaDB and PHP-FPM ports are not published to the host.

## Start the project

From the repository root:

```bash
make
```

For an already-built project:

```bash
make up
```

Check status:

```bash
make ps
```

All three containers should be running and eventually report healthy.

## Stop the project

Preserve data while removing containers and the network:

```bash
make down
```

Stop containers without removing them:

```bash
make stop
```

Restart stopped containers:

```bash
make start
```

## Access the website

Replace `<login>` with the value in `srcs/.env`:

```text
https://<login>.42.fr
```

The certificate is self-signed, so the browser may display a local security warning.

## Access the administration panel

```text
https://<login>.42.fr/wp-admin
```

The administrator username is stored as `WP_ADMIN_USER` in `srcs/.env`. The administrator password is stored locally in:

```text
secrets/wp_admin_password.txt
```

Display it only in a private terminal:

```bash
cat secrets/wp_admin_password.txt
```

## Credentials

Non-secret values and usernames:

```text
srcs/.env
```

Secret values:

```text
secrets/db_root_password.txt
secrets/db_password.txt
secrets/wp_admin_password.txt
secrets/wp_user_password.txt
```

The secret files must have restrictive permissions and must never be committed. Check:

```bash
ls -l secrets

git status --ignored
```

## Verify service health

```bash
make ps
make verify
```

Inspect recent logs:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs --tail=100
```

Inspect one service:

```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

Check the website directly:

```bash
. srcs/.env
curl --insecure --resolve "${DOMAIN_NAME}:443:127.0.0.1" "https://${DOMAIN_NAME}/healthz"
```

Expected response:

```text
ok
```

## Persistent data

Database files:

```text
/home/<login>/data/mariadb
```

WordPress files:

```text
/home/<login>/data/wordpress
```

`make down` preserves this data. `make purge` deletes it permanently and requires a typed confirmation.

## Basic recovery

If a container is unhealthy:

```bash
make ps
make logs
```

Then restart the stack:

```bash
make down
make up
```

Do not delete the data directories unless a complete reset is intended.
