*This project has been created as part of the 42 curriculum by hhurnik.*

# Inception

## Description

Inception is a small containerized web infrastructure built from custom Docker images. The stack contains exactly three mandatory services:

- **NGINX** is the only public entry point. It accepts HTTPS traffic on host port `443` and permits TLS 1.2 and TLS 1.3 only.
- **WordPress with PHP-FPM** executes the PHP application. It does not contain NGINX.
- **MariaDB** stores the WordPress database. It does not contain NGINX.

Every service runs in its own container and is built from `debian:12.14-slim`, the current penultimate stable Debian release at the time this project was prepared. No ready-made NGINX, WordPress, or MariaDB application image is used.

```text
Browser
   |
   | HTTPS :443, TLS 1.2/1.3
   v
 NGINX
   |
   | FastCGI :9000 on the private Docker network
   v
 WordPress + PHP-FPM
   |
   | MariaDB protocol :3306 on the private Docker network
   v
 MariaDB
```

Two top-level Docker named volumes persist data:

- `wordpress_data` stores `/var/www/html` in `/home/<login>/data/wordpress` on the host.
- `mariadb_data` stores `/var/lib/mysql` in `/home/<login>/data/mariadb` on the host.

The services mount named volumes, not service-level host-path mounts. The local volume driver is configured so that the named volumes store their data in the host paths required by the subject.

## Project sources

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── LEARNING_GUIDE_PL.md
├── EVALUATION_CHECKLIST.md
├── secrets
│   ├── .gitkeep
│   └── README.md
└── srcs
    ├── .env.example
    ├── docker-compose.yml
    └── requirements
        ├── mariadb
        │   ├── Dockerfile
        │   ├── conf/99-inception.cnf
        │   └── tools
        │       ├── entrypoint.sh
        │       └── healthcheck.sh
        ├── nginx
        │   ├── Dockerfile
        │   ├── conf/nginx.conf.template
        │   └── tools/entrypoint.sh
        ├── wordpress
        │   ├── Dockerfile
        │   ├── conf
        │   │   ├── php-fpm.conf
        │   │   ├── wordpress.ini
        │   │   └── www.conf
        │   └── tools
        │       ├── entrypoint.sh
        │       └── healthcheck.sh
        └── tools
            ├── setup.sh
            ├── static-check.sh
            ├── verify-runtime.sh
            ├── purge-data.sh
            └── remove-polish-comments.sh
```

## Main design choices

### Virtual Machines vs Docker

A virtual machine emulates a complete machine and normally runs a full guest operating system with its own kernel-facing environment. A Docker container packages an application and its userspace dependencies while sharing the host kernel. The VM provides the isolated host required by the project; Docker then isolates and connects the individual services inside that VM.

### Secrets vs Environment Variables

Environment variables are suitable for non-confidential configuration such as the domain, database name, and usernames. Passwords are confidential and are therefore stored in local files under `secrets/`, ignored by Git, and mounted into only the containers that require them through Docker Compose secrets. Password values are not present in Dockerfiles, Compose, `.env`, or the repository history.

### Docker Network vs Host Network

The custom bridge network `inception` provides container-name DNS and isolates internal traffic. WordPress connects to `mariadb:3306`, and NGINX connects to `wordpress:9000`. Host networking is not used. Only NGINX publishes a host port, and that port is `443`.

### Docker Volumes vs Bind Mounts

Docker named volumes are lifecycle-managed Docker objects and are mounted into services by volume name. Ordinary bind mounts directly couple a service to an arbitrary host path. This project declares named volumes at the top level and uses the local volume driver to place their persistent storage under `/home/<login>/data`, as explicitly required by the subject.

## Security choices

- Only NGINX publishes a port.
- TLS 1.0 and TLS 1.1 are disabled.
- The TLS private key is generated at container startup and is never committed.
- Passwords are local Docker Compose secrets.
- The WordPress database password is read by `wp-config.php` from `/run/secrets/db_password` rather than being copied into the persistent WordPress volume.
- WordPress file editing from the administration panel is disabled.
- NGINX denies direct access to `wp-config.php` and hidden files.
- Containers use `no-new-privileges`.
- Each service runs its real foreground process as PID 1 through `exec`; no infinite-loop keepalive command is used.
- Service health checks control startup ordering.
- All images use an explicit Debian tag; no `latest` tag is used.

The development certificate is self-signed because the domain is local. A browser warning is expected until the certificate is trusted locally.

## Instructions

### Prerequisites

The target machine must provide:

- a Linux virtual machine;
- Docker Engine;
- Docker Compose v2 (`docker compose`);
- GNU Make;
- Git, OpenSSL, and standard POSIX tools;
- permission to create `/home/<login>/data` and edit `/etc/hosts`.

### First launch

```bash
git clone <repository-url> inception
cd inception
make
```

On the first run, `make setup` asks for the learner login and non-secret usernames. It creates:

- `srcs/.env`;
- four random 64-character hexadecimal secret files;
- `/home/<login>/data/mariadb`;
- `/home/<login>/data/wordpress`;
- a local `/etc/hosts` entry for `<login>.42.fr`.

Then `make` validates, builds, and starts the stack.

Open:

```text
https://<login>.42.fr
https://<login>.42.fr/wp-admin
```

Read the generated WordPress credentials locally:

```bash
cat secrets/wp_admin_password.txt
cat secrets/wp_user_password.txt
```

Never commit those files.

### Common commands

```bash
make ps
make logs
make down
make up
make verify
make fclean
make purge
```

`make down` preserves data. `make purge` permanently deletes the host data after an explicit confirmation.

See `USER_DOC.md` for operator instructions and `DEV_DOC.md` for setup, architecture, maintenance, and debugging details.

## Resources

- Docker Compose documentation: https://docs.docker.com/compose/
- Compose services reference: https://docs.docker.com/reference/compose-file/services/
- Compose networks reference: https://docs.docker.com/reference/compose-file/networks/
- Compose volumes reference: https://docs.docker.com/reference/compose-file/volumes/
- Compose secrets guide: https://docs.docker.com/compose/how-tos/use-secrets/
- Dockerfile best practices: https://docs.docker.com/build/building/best-practices/
- Debian releases: https://www.debian.org/releases/
- NGINX documentation: https://nginx.org/en/docs/
- MariaDB Server documentation: https://mariadb.com/docs/server/
- WordPress release archive: https://wordpress.org/download/releases/
- WP-CLI handbook: https://make.wordpress.org/cli/handbook/
- PHP-FPM documentation: https://www.php.net/manual/en/install.fpm.php

### Use of AI

AI was used to help structure the project, explain Docker and system-administration concepts, draft configuration and documentation, identify security-sensitive areas, and propose validation commands.
