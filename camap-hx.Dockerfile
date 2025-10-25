FROM node:20.12.1

# Paquets système (⚠️ on N'installe PAS 'haxe' via APT)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git curl ca-certificates tar \
      imagemagick apache2 \
      neko libapache2-mod-neko \
      libxml-twig-perl libutf8-all-perl procps && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Installer Haxe 4.0.5 (binaire officiel) ---
RUN set -eux; \
  curl -fsSL https://github.com/HaxeFoundation/haxe/releases/download/4.0.5/haxe-4.0.5-linux64.tar.gz -o /tmp/haxe.tgz; \
  mkdir -p /opt/haxe-4.0.5 && tar -xzf /tmp/haxe.tgz -C /opt/haxe-4.0.5 --strip-components=1; \
  ln -sf /opt/haxe-4.0.5/haxe /usr/local/bin/haxe; \
  ln -sf /opt/haxe-4.0.5/haxelib /usr/local/bin/haxelib; \
  haxe -version

# Environnement
ENV TZ="Europe/Paris"
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_LOG_DIR=/var/log/apache2
ENV VERSION=unknown
# Dépôt haxelib partagé
ENV HAXELIB_PATH=/usr/share/haxelib

# Apache: logs -> stdout/err + modules + docroot
RUN ln -sf /proc/self/fd/1 /var/log/apache2/access.log && \
    ln -sf /proc/self/fd/1 /var/log/apache2/error.log && \
    a2enmod rewrite && a2enmod neko && \
    sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf && \
    sed -i 's!/var/www!/srv/www!' /etc/apache2/apache2.conf && \
    sed -i 's!Options Indexes FollowSymLinks!Options FollowSymLinks!' /etc/apache2/apache2.conf && \
    sed -i 's!/var/www/html!/srv/www!g' /etc/apache2/sites-available/000-default.conf

# Préparer stockage haxelib et droits
RUN mkdir -p "$HAXELIB_PATH" /srv /var/www && chown -R www-data:www-data "$HAXELIB_PATH" /srv /var/www

# Code (on n'embarque pas config.xml; il sera monté au run)
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
# Backend (Haxe/Haxelib)
# ========================
WORKDIR /srv/backend
# Initialiser haxelib pour www-data et installer les libs du backend
RUN haxelib setup "$HAXELIB_PATH" \
 && rm -rf haxe_libraries || true \
 && yes | haxelib install build.hxml \
 && mkdir -p haxe_libraries \
 && [ -f haxe_libraries/haxe.hxml ] || printf -- '-D haxe=4.0.5\n' > haxe_libraries/haxe.hxml \
 && haxe -v build.hxml -D i18n_generation

# Répertoires requis et droits (tmp + files)
USER root
RUN install -d -m 0777 /srv/lang/master/tmp \
 && install -d -o www-data -g www-data /srv/www/file
USER www-data

# ========================
# Frontend (Haxe/Haxelib + npm si présent)
# ========================
WORKDIR /srv/frontend
RUN haxelib setup "$HAXELIB_PATH" \
 && rm -rf haxe_libraries || true \
 && yes | haxelib install build.hxml \
 && mkdir -p haxe_libraries \
 && [ -f haxe_libraries/haxe.hxml ] || printf -- '-D haxe=4.0.5\n' > haxe_libraries/haxe.hxml \
 && ( [ -f package.json ] && npm install || true ) \
 && haxe -v build.hxml

# ========================
# Génération des templates (cohérent avec build.hxml: .../lang/master/tpl)
# ========================
WORKDIR /srv/lang/master/tpl
RUN neko ../../../backend/temploc2.n -macros macros.mtt -output ../tmp/ *.mtt */*.mtt */*/*.mtt

# Finalisation
USER root
RUN echo "Europe/Paris" > /etc/timezone

# Healthcheck (Apache doit répondre sur /)
HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -fsS http://127.0.0.1/ || exit 1

ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
