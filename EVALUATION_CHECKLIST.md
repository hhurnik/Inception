# Evaluation Checklist

## Repository

- [ ] `README.md`, `USER_DOC.md`, and `DEV_DOC.md` exist at the repository root.
- [ ] The first README line contains the real learner login and is italicized.
- [ ] `srcs/.env` exists locally but is ignored by Git.
- [ ] No `secrets/*.txt` file is tracked.
- [ ] No password, API key, or private key is present in Git history.
- [ ] Every service has its own Dockerfile.
- [ ] No Dockerfile uses a `latest` tag.
- [ ] Images are named exactly `nginx`, `wordpress`, and `mariadb`.

## Runtime architecture

- [ ] Exactly three mandatory containers are running.
- [ ] Only NGINX publishes host port `443`.
- [ ] Port `80` is not published.
- [ ] MariaDB and PHP-FPM ports are internal only.
- [ ] All containers use the explicitly declared `inception` network.
- [ ] `network_mode: host`, `links`, and `--link` are absent.
- [ ] Restart policies are configured.
- [ ] No prohibited keepalive command, infinite loop, or interactive shell is the main command.
- [ ] Each final process runs in the foreground through `exec`.

## TLS and NGINX

- [ ] `https://<login>.42.fr` loads the site.
- [ ] TLS 1.2 succeeds.
- [ ] TLS 1.3 succeeds.
- [ ] TLS 1.1 fails.
- [ ] NGINX is the only service containing NGINX.
- [ ] `wp-config.php` cannot be downloaded.

## WordPress

- [ ] WordPress runs through PHP-FPM without NGINX in the same container.
- [ ] Two WordPress users exist.
- [ ] One user is an administrator.
- [ ] The administrator login does not contain `admin` in any letter case.
- [ ] The second user has the configured non-administrator role.
- [ ] The administration panel is reachable at `/wp-admin`.

## MariaDB

- [ ] MariaDB runs without NGINX.
- [ ] The WordPress database exists.
- [ ] A dedicated database user exists.
- [ ] The database user is not the root account.
- [ ] Root is not exposed for remote application access.

## Persistence

- [ ] Two Docker named volumes exist.
- [ ] Database data is stored under `/home/<login>/data/mariadb`.
- [ ] WordPress files are stored under `/home/<login>/data/wordpress`.
- [ ] A post survives `make down && make up`.
- [ ] Users survive container recreation.

## Commands

```bash
make check
make
make ps
make verify
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
docker network inspect inception
docker volume inspect wordpress_data mariadb_data
git status --ignored
git grep -nEi 'password|passwd|secret|credential'
```
