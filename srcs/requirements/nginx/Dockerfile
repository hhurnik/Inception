# [EN] Debian 12 is the penultimate stable Debian release at project preparation time.
# [PL] Debian 12 jest przedostatnim stabilnym wydaniem Debiana w czasie przygotowania projektu.
FROM debian:12.14-slim

# [EN] Prevent Debian package scripts from attempting to start system services during image build.
# [PL] Zablokuj próby uruchamiania usług systemowych przez skrypty pakietów podczas budowania obrazu.
RUN set -eux; \
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; \
    chmod +x /usr/sbin/policy-rc.d; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gettext-base \
        nginx \
        openssl; \
    rm -f /usr/sbin/policy-rc.d; \
    rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default; \
    mkdir -p /etc/nginx/templates /etc/nginx/tls /run/nginx

# [EN] The template is rendered at runtime because the learner domain is environment-specific.
# [PL] Szablon jest renderowany podczas startu, ponieważ domena ucznia zależy od środowiska.
COPY conf/nginx.conf.template /etc/nginx/templates/nginx.conf.template
COPY tools/entrypoint.sh /usr/local/bin/nginx-entrypoint.sh
RUN chmod 0755 /usr/local/bin/nginx-entrypoint.sh

# [EN] EXPOSE documents the container port; Compose is what publishes host port 443.
# [PL] EXPOSE dokumentuje port kontenera; to Compose publikuje port 443 hosta.
EXPOSE 443

STOPSIGNAL SIGQUIT
ENTRYPOINT ["/usr/local/bin/nginx-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
