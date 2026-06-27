# Debian 12 is the penultimate stable Debian release at project preparation time.
FROM debian:12.14-slim

ARG WP_CLI_VERSION=2.12.0
ARG WORDPRESS_VERSION=7.0

# Install PHP-FPM and only the runtime modules needed by a typical WordPress installation.
RUN set -eux; \
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; \
    chmod +x /usr/sbin/policy-rc.d; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libfcgi-bin \
        mariadb-client \
        openssl \
        php8.2-cli \
        php8.2-curl \
        php8.2-fpm \
        php8.2-gd \
        php8.2-intl \
        php8.2-mbstring \
        php8.2-mysql \
        php8.2-opcache \
        php8.2-xml \
        php8.2-zip \
        unzip; \
    rm -f /usr/sbin/policy-rc.d; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /run/php /usr/src/wordpress /var/www/html

# Download a pinned WP-CLI release and verify its published SHA-512 checksum.
RUN set -eux; \
    cd /tmp; \
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 \
        -o "wp-cli-${WP_CLI_VERSION}.phar" \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar"; \
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 \
        -o "wp-cli-${WP_CLI_VERSION}.phar.sha512" \
        "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar.sha512"; \
    CHECKSUM="$(cat "wp-cli-${WP_CLI_VERSION}.phar.sha512")"; \
    printf '%s  %s\n' "${CHECKSUM}" "wp-cli-${WP_CLI_VERSION}.phar" | sha512sum -c -; \
    install -m 0755 "wp-cli-${WP_CLI_VERSION}.phar" /usr/local/bin/wp; \
    rm -f "wp-cli-${WP_CLI_VERSION}.phar" "wp-cli-${WP_CLI_VERSION}.phar.sha512"; \
    wp --allow-root --info

# WordPress core is downloaded and checksum-verified at image build time.
RUN set -eux; \
    wp core download \
        --allow-root \
        --path=/usr/src/wordpress \
        --version="$WORDPRESS_VERSION" \
        --locale=en_US \
        --force; \
    chown -R www-data:www-data /usr/src/wordpress /var/www/html

COPY conf/php-fpm.conf /etc/php/8.2/fpm/php-fpm.conf
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY conf/wordpress.ini /etc/php/8.2/fpm/conf.d/99-wordpress.ini
COPY tools/entrypoint.sh /usr/local/bin/wordpress-entrypoint.sh
COPY tools/healthcheck.sh /usr/local/bin/wordpress-healthcheck.sh
RUN chmod 0755 /usr/local/bin/wordpress-entrypoint.sh /usr/local/bin/wordpress-healthcheck.sh

WORKDIR /var/www/html
EXPOSE 9000
STOPSIGNAL SIGQUIT
ENTRYPOINT ["/usr/local/bin/wordpress-entrypoint.sh"]
CMD ["php-fpm8.2", "-F"]
