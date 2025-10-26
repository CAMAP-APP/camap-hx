# ===========================
# Stage 1 : builder (Haxe via lix)
# ===========================
FROM node:20.12.1 AS builder

# Outils build (git/SSL) + Neko (pour temploc2.n)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl ca-certificates neko \
    && rm -rf /var/lib/apt/lists/*

# lix figé
RUN npm i -g lix@15.12.4 && lix --version

ENV HAXE_VERSION=4.0.5
ENV HOME=/var/www
ENV HAXE_LIBCACHE=/var/www/.haxe/libcache
ENV HAXE_STD_PATH=/var/www/.haxe/versions/${HAXE_VERSION}/std

# Repo haxelib (idempotent)
RUN mkdir -p /var/www/haxelib /var/www/.haxe/versions /var/www/.haxe/libcache && \
    printf '%s\n' "/var/www/haxelib" | haxelib setup

WORKDIR /srv

# ---------------------------
# Dépendances BACKEND (cache)
# ---------------------------
COPY backend/haxe_libraries/ /srv/backend/haxe_libraries/
COPY backend/build.hxml       /srv/backend/build.hxml

WORKDIR /srv/backend
RUN set -eux; \
    lix scope create; \
    lix install haxe "${HAXE_VERSION}"; \
    lix use haxe   "${HAXE_VERSION}"; \
    lix download; \
    mkdir -p haxe_libraries; \
    printf -- '-D haxe=%s\n' "${HAXE_VERSION}" > haxe_libraries/haxe.hxml

# ---------------------------
# Dépendances FRONTEND (cache)
# ---------------------------
WORKDIR /srv
COPY frontend/haxe_libraries/  /srv/frontend/haxe_libraries/
COPY frontend/build.hxml        /srv/frontend/build.hxml
COPY frontend/package.json      /srv/frontend/package.json
COPY frontend/package-lock.json /srv/frontend/package-lock.json

WORKDIR /srv/frontend
RUN set -eux; \
    lix scope create; \
    lix install haxe "${HAXE_VERSION}"; \
    lix use haxe   "${HAXE_VERSION}"; \
    lix download; \
    mkdir -p haxe_libraries; \
    printf -- '-D haxe=%s\n' "${HAXE_VERSION}" > haxe_libraries/haxe.hxml; \
    [ -f package.json ] && npm ci --no-audit --no-fund || true

# ---------------------------
# Copier le code + config.dist, puis build
# ---------------------------
WORKDIR /srv
COPY common/   /srv/common/
COPY data/     /srv/data/
COPY js/       /srv/js/
COPY lang/     /srv/lang/
COPY src/      /srv/src/
COPY www/      /srv/www/
COPY backend/  /srv/backend/
COPY frontend/ /srv/frontend/
# >>> Ajout clé : fournir un config.xml pour le build backend
COPY config.xml.dist /srv/config.xml

# Build backend (index.n)
WORKDIR /srv/backend
RUN set -eux; \
    # npx utilise le shim node_modules/.bin/haxe installé par lix pour ce scope
    npx haxe -version; \
    npx haxe -v build.hxml -D i18n_generation

# Build frontend (js/app.js)
WORKDIR /srv/frontend
RUN set -eux; \
    npx haxe -v build.hxml

# Génération des templates (lang/master/tpl -> lang/master/tmp)
WORKDIR /srv/lang/master/tpl
RUN set -eux; \
    neko ../../../backend/temploc2.n -macros macros.mtt -output ../tmp/ *.mtt */*.mtt */*/*.mtt


# ===========================
# Stage 2 : runtime (Apache + Neko)
# ===========================
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      apache2 libapache2-mod-neko neko curl ca-certificates \
      libxml-twig-perl libutf8-all-perl \
    && rm -rf /var/lib/apt/lists/*

ENV TZ="Europe/Paris" \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_LOG_DIR=/var/log/apache2

# Logs -> stdout/err + rewrite + docroot
RUN ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/2 /var/log/apache2/error.log && \
    a2enmod rewrite neko && \
    sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf && \
    sed -i 's!/var/www!/srv/www!' /etc/apache2/apache2.conf && \
    sed -i 's!Options Indexes FollowSymLinks!Options FollowSymLinks!' /etc/apache2/apache2.conf && \
    sed -i 's!/var/www/html!/srv/www!g' /etc/apache2/sites-available/000-default.conf

WORKDIR /srv
# On ne copie QUE les artefacts utiles
COPY --from=builder /srv/www  /srv/www
COPY --from=builder /srv/lang  /srv/lang
# (Note : pas de /srv/config.xml dans l'image finale)

RUN set -eux; \
    [ -f /srv/www/robots.txt ] || { echo "User-agent: *"; echo "Disallow: /"; echo "Allow: /group/"; } > /srv/www/robots.txt; \
    install -d -m 0777 /srv/lang/master/tmp; \
    install -d -o www-data -g www-data /srv/www/file

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -fsS http://127.0.0.1/ || exit 1
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
