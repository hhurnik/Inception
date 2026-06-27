# Debian 12 is the penultimate stable Debian release at project preparation time.
FROM debian:12.14-slim

# Install MariaDB from Debian repositories instead of using a ready-made application image.
RUN set -eux; \
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; \
    chmod +x /usr/sbin/policy-rc.d; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        mariadb-client \
        mariadb-server; \
    rm -f /usr/sbin/policy-rc.d; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /var/lib/mysql/*; \
    mkdir -p /run/mysqld /var/lib/mysql; \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql

COPY conf/99-inception.cnf /etc/mysql/mariadb.conf.d/99-inception.cnf
COPY tools/entrypoint.sh /usr/local/bin/mariadb-entrypoint.sh
COPY tools/healthcheck.sh /usr/local/bin/mariadb-healthcheck.sh
RUN chmod 0755 /usr/local/bin/mariadb-entrypoint.sh /usr/local/bin/mariadb-healthcheck.sh

STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/local/bin/mariadb-entrypoint.sh"]
CMD ["mariadbd"]
