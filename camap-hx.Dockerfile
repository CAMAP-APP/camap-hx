FROM node:20.12.1

# Paquets système (⚠️ pas de 'haxe' via APT pour éviter les collisions avec Lix)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl ca-certificates \
      imagemagick apache2 \
      neko libapache2-mod-neko \
      libxml-twig-perl libutf8-all-perl procps && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV TZ="Europe/Paris"
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_LOG_DIR=/var/log/apache2
# Surchargé par CI/CD si besoin
ENV VERSION=unknown

# logs -> stdout/err + modules + docroot
RUN ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/1 /var/log/apache2/error.log && \
    a2enmod rewrite && a2enmod neko && \
    sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf && \
    sed -i 's!/var/www!/srv/www!' /etc/apache2/apache2.conf && \
    sed -i 's!Options Indexes FollowSymLinks!Options FollowSymLinks!' /etc/apache2/apache2.conf && \
    sed -i 's!/var/www/html!/srv/www!g' /etc/apache2/sites-available/000-default.conf

# Préparer /srv et /var/www
RUN mkdir -p /srv /var/www && chown -R www-data:www-data /srv /var/www

# --- Code (ne PAS embarquer config.xml; il sera monté au run) ---
# Si ton contexte de build est la racine du repo camap-hx :
COPY --chown=www-data:www-data ./common/   /srv/common/
COPY --chown=www-data:www-data ./data/     /srv/data/
COPY --chown=www-data:www-data ./js/       /srv/js/
COPY --chown=www-data:www-data ./lang/     /srv/lang/
COPY --chown=www-data:www-data ./src/      /srv/src/
COPY --chown=www-data:www-data ./www/      /srv/www/
COPY --chown=www-data:www-data ./backend/  /srv/backend/
COPY --chown=www-data:www-data ./frontend/ /srv/frontend/

USER www-data

# robots.txt minimal
WORKDIR /srv/www
RUN { echo "User-agent: *"; echo "Disallow: /"; echo "Allow: /group/"; } > robots.txt

# ========================
# Backend (Lix + Haxe)
# ========================
WORKDIR /srv/backend
RUN set -eux; \
  # 0) S'assurer d'avoir un package.json pour installer haxeshim
  if [ ! -f package.json ]; then printf '{ "name":"camap-hx-backend","private":true }' > package.json; fi; \
  # 1) Installer le shim Haxe (fournit npx haxe / haxelib)
  npm i -D haxeshim --no-audit --no-fund; \
  # 2) Préparer Lix (scope + toolchain Haxe + libs depuis haxe_libraries/*)
  npx lix scope create; \
  npx lix install haxe 4.0.5; \
  npx lix use haxe 4.0.5; \
  npx lix download; \
  # 3) Marqueur de version attendu par certains projets
  mkdir -p haxe_libraries; \
  printf -- '-D haxe=4.0.5\n' > haxe_libraries/haxe.hxml; \
  # 4) Compiler via le shim (utilise la toolchain Lix sélectionnée)
  npx haxe -version; \
  npx haxe -v build.hxml -D i18n_generation




# Dossiers nécessaires et droits (tmp + files)
USER root
# Aligne ici 'master' ou 'fr' selon ce que tu utilises dans build.hxml
RUN install -d -m 0777 /srv/lang/master/tmp && \
    install -d -o www-data -g www-data /srv/www/file
USER www-data

# ========================
# Frontend (Lix + Haxe + npm si présent)
# ========================
WORKDIR /srv/frontend
RUN set -eux; \
  # 0) S'assurer d'avoir un package.json (le tien existe a priori déjà)
  if [ ! -f package.json ]; then printf '{ "name":"camap-hx-frontend","private":true }' > package.json; fi; \
  # 1) Installer le shim Haxe
  npm i -D haxeshim --no-audit --no-fund; \
  # 2) Préparer Lix
  npx lix scope create; \
  npx lix install haxe 4.0.5; \
  npx lix use haxe 4.0.5; \
  npx lix download; \
  # 3) Dépendances JS éventuelles
  ( [ -f package.json ] && npm install --no-audit --no-fund || true ); \
  # 4) Marqueur Haxe
  mkdir -p haxe_libraries; \
  printf -- '-D haxe=4.0.5\n' > haxe_libraries/haxe.hxml; \
  # 5) Compiler
  npx haxe -v build.hxml




# ========================
# Génération des templates
#   ⚠️ Aligne le dossier 'master' vs 'fr' avec ce que tu as mis plus haut
# ========================
WORKDIR /srv/lang/master/tpl/
RUN neko ../../../backend/temploc2.n -macros macros.mtt -output ../tmp/ *.mtt */*.mtt */*/*.mtt

# Finalisation
USER root
RUN echo "Europe/Paris" > /etc/timezone

# healthcheck simple
HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -fsS http://127.0.0.1/ || exit 1

ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
