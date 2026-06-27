# Developer Documentation

## Prerequisites

Use a Linux virtual machine with Docker Engine, Docker Compose v2, Make, Git, OpenSSL, and permission to use `sudo` for the required data directories and `/etc/hosts` entry.

Verify:

```bash
docker --version
docker compose version
make --version
git --version
openssl version
```

## Environment setup from scratch

Clone and enter the project:

```bash
git clone <repository-url> inception
cd inception
```

Create local configuration and secrets:

```bash
make setup
```

The setup script is idempotent. Existing secrets are not overwritten.

Review non-secret configuration:

```bash
cat srcs/.env
```

Expected variables:

```text
LOGIN
DOMAIN_NAME
MYSQL_DATABASE
MYSQL_USER
WP_TITLE
WP_ADMIN_USER
WP_ADMIN_EMAIL
WP_USER
WP_USER_EMAIL
WP_USER_ROLE
```

Passwords must not be added to `.env`.

## Build and launch

Full workflow:

```bash
make
```

Separate steps:

```bash
make check
make config
make build
make up
```

Compose command used by the Makefile:

```bash
docker compose --env-file srcs/.env -f srcs/docker-compose.yml
```

## Service architecture

### MariaDB

- Image name: `mariadb`
- Container name: `mariadb`
- Main process: `mariadbd`
- Persistent path: `/var/lib/mysql`
- Internal port: `3306`
- Secrets: database root password and WordPress database password

The entrypoint initializes the database only if `/var/lib/mysql/mysql` does not exist. It starts a temporary local-only MariaDB process, creates the database and account, stops the temporary process, and finally replaces the shell with the production `mariadbd` process.

### WordPress

- Image name: `wordpress`
- Container name: `wordpress`
- Main process: `php-fpm8.2 -F`
- Persistent path: `/var/www/html`
- Internal port: `9000`
- Secrets: database password and two WordPress passwords

WordPress core is downloaded into the image at build time. On first startup it is copied into the empty persistent volume. WP-CLI creates `wp-config.php`, installs WordPress, and creates the second user. The database password remains a runtime file reference to `/run/secrets/db_password`.

### NGINX

- Image name: `nginx`
- Container name: `nginx`
- Main process: `nginx -g 'daemon off;'`
- Published port: `443`

The entrypoint creates a self-signed certificate with the configured domain as a Subject Alternative Name, renders the NGINX template, validates the configuration, and executes NGINX in the foreground.

## Container management

```bash
make ps
make logs
make restart
make down
make up
```

Open a diagnostic shell only for debugging, not as a container keepalive process:

```bash
docker exec -it nginx sh
docker exec -it wordpress sh
docker exec -it mariadb sh
```

Inspect health:

```bash
docker inspect --format '{{json .State.Health}}' nginx | jq
docker inspect --format '{{json .State.Health}}' wordpress | jq
docker inspect --format '{{json .State.Health}}' mariadb | jq
```

## Images, network, and volumes

```bash
docker image ls nginx wordpress mariadb
docker network inspect inception
docker volume inspect wordpress_data
docker volume inspect mariadb_data
```

Only NGINX should publish a host port:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

## Persistence tests

1. Create a WordPress post.
2. Record the current users:

```bash
docker exec wordpress wp user list --allow-root --path=/var/www/html
```

3. Recreate containers:

```bash
make down
make up
```

4. Confirm the post and users remain.

A destructive test requires `make purge` and must never be run on data that should be retained.

## Debugging order

1. Validate local files:

```bash
make check
make config
```

2. Check states:

```bash
make ps
```

3. Read MariaDB logs first, then WordPress, then NGINX:

```bash
docker logs mariadb
docker logs wordpress
docker logs nginx
```

4. Check internal DNS and ports:

```bash
docker exec wordpress getent hosts mariadb
docker exec nginx getent hosts wordpress
```

5. Run the full validation:

```bash
make verify
```

## Cleanup

Safe removal of containers and network:

```bash
make clean
```

Removal of containers, local images, and Docker volume objects while preserving required host data:

```bash
make fclean
```

Complete destructive reset:

```bash
make purge
```

## Moving to another machine

Commit only source and documentation:

```bash
git status
git add .
git diff --cached
git commit -m "Implement Inception stack"
git push
```

On the destination machine:

```bash
git clone <repository-url> inception
cd inception
make
```

The destination machine creates a fresh `.env`, fresh secrets, and fresh data directories. Persistent data is not transferred by Git.
