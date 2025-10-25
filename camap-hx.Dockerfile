FROM node:20.12.1
RUN apt-get update && \
    apt-get install -y git curl imagemagick apache2 haxe neko libapache2-mod-neko libxml-twig-perl libutf8-all-perl procps && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- installer Haxe 4.0.5 (binaire officiel) ---
RUN set -eux; \
  curl -fsSL https://github.com/HaxeFoundation/haxe/releases/download/4.0.5/haxe-4.0.5-linux64.tar.gz -o /tmp/haxe.tgz; \
  mkdir -p /opt/haxe-4.0.5 && tar -xzf /tmp/haxe.tgz -C /opt/haxe-4.0.5 --strip-components=1; \
  ln -sf /opt/haxe-4.0.5/haxe /usr/local/bin/haxe; \
  ln -sf /opt/haxe-4.0.5/haxelib /usr/local/bin/haxelib; \
  haxe -version

ENV TZ="Europe/Paris"
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_LOG_DIR=/var/log/apache2
ENV VERSION=unknown

# logs -> stdout/err
RUN ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/1 /var/log/apache2/error.log
RUN a2enmod rewrite && a2enmod neko
RUN sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
RUN sed -i 's!/var/www!/srv/www!' /etc/apache2/apache2.conf
RUN sed -i 's!Options Indexes FollowSymLinks!Options FollowSymLinks!' /etc/apache2/apache2.conf
RUN sed -i 's!/var/www/html!/srv/www!g' /etc/apache2/sites-available/000-default.conf

# haxe libs
RUN npm install -g lix
RUN chown www-data:www-data /srv /var/www
RUN haxelib setup /usr/share/haxelib && haxelib install templo && cd /usr/bin && haxelib run templo

# code
COPY --chown=www-data:www-data ./common/   /srv/common/
COPY --chown=www-data:www-data ./data/     /srv/data/
COPY --chown=www-data:www-data ./js/       /srv/js/
COPY --chown=www-data:www-data ./lang/     /srv/lang/
COPY --chown=www-data:www-data ./src/      /srv/src/
COPY --chown=www-data:www-data ./www/      /srv/www/
COPY --chown=www-data:www-data ./backend/  /srv/backend/
COPY --chown=www-data:www-data ./frontend/ /srv/frontend/
# ⚠️ plus de COPY de config.xml ici

USER www-data

WORKDIR /srv/www
RUN { echo "User-agent: *"; echo "Disallow: /"; echo "Allow: /group/"; } > robots.txt

WORKDIR /srv/backend
RUN lix scope create && lix install haxe 4.0.5 && lix use haxe 4.0.5 && lix download

WORKDIR /srv/frontend
RUN lix scope create && lix use haxe 4.0.5 && lix download && npm install

WORKDIR /srv
RUN set -eux; \
    echo "=== Tree (backend/frontend/lang/www) ==="; \
    ls -la || true; \
    ls -la backend || true; \
    ls -la frontend || true; \
    ls -la lang || true; \
    ls -la www || true

# backend
WORKDIR /srv/backend
# Si ton build.hxml contient "-lib haxe", garde-le mais fournis le "marqueur" attendu :
RUN set -eux; \
  mkdir -p haxe_libraries; \
  [ -f haxe_libraries/haxe.hxml ] || printf -- '-D haxe=4.0.5\n' > haxe_libraries/haxe.hxml; \
  haxe -v build.hxml -D i18n_generation

USER root
RUN install -d -m 0777 ../lang/fr/tmp
RUN install -d -o www-data -g www-data ../www/file
USER www-data

# frontend
WORKDIR /srv/frontend
RUN haxe -v build.hxml

WORKDIR /srv/lang/fr/tpl/
RUN neko ../../../backend/temploc2.n -macros macros.mtt -output ../tmp/ *.mtt */*.mtt */*/*.mtt

WORKDIR /srv
USER root
RUN echo "Europe/Paris" > /etc/timezone

# healthcheck simple (optionnel)
HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -fsS http://127.0.0.1/ || exit 1

ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
