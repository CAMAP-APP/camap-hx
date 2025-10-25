FROM node:20.12.1

# Paquets système (⚠️ on retire 'haxe' du apt-get)
RUN apt-get update && \
    apt-get install -y git curl ca-certificates tar imagemagick apache2 \
                       neko libapache2-mod-neko libxml-twig-perl \
                       libutf8-all-perl procps && \
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

# haxelib + templo
RUN chown www-data:www-data /srv /var/www
RUN haxelib setup /usr/share/haxelib \
 && haxelib install templo \
 && cd /usr/bin && haxelib run templo

# ----- haxelib partagé et init pour www-data -----
# haxelib + templo (init pour www-data, sans exécution)
ENV HAXELIB_PATH=/usr/share/haxelib
RUN mkdir -p /usr/share/haxelib && chown -R www-data:www-data /usr/share/haxelib
USER www-data
RUN haxelib setup /usr/share/haxelib && haxelib install templo

# code
COPY --chown=www-data:www-data ./common/   /srv/common/
COPY --chown=www-data:www-data ./data/     /srv/data/
COPY --chown=www-data:www-data ./js/       /srv/js/
COPY --chown=www-data:www-data ./lang/     /srv/lang/
COPY --chown=www-data:www-data ./src/      /srv/src/
COPY --chown=www-data:www-data ./www/      /srv/www/
COPY --chown=www-data:www-data ./backend/  /srv/backend/
COPY --chown=www-data:www-data ./frontend/ /srv/frontend/
# ⚠️ plus de COPY de config.xml ici (il sera monté au run)

USER www-data

WORKDIR /srv/www
RUN { echo "User-agent: *"; echo "Disallow: /"; echo "Allow: /group/"; } > robots.txt

# backend
WORKDIR /srv/backend
# Si build.hxml contenait '-lib haxe', fournir le marqueur attendu :
RUN mkdir -p haxe_libraries \
 && [ -f haxe_libraries/haxe.hxml ] || printf -- '-D haxe=4.0.5\n' > haxe_libraries/haxe.hxml \
 && haxe -v build.hxml -D i18n_generation

# créer les répertoires requis avec les bons droits
USER root
RUN install -d -m 0777 /srv/lang/fr/tmp \
 && install -d -o www-data -g www-data /srv/www/file
USER www-data

# frontend
WORKDIR /srv/frontend
RUN haxe -v build.hxml

# génération des templates
WORKDIR /srv/lang/fr/tpl/
RUN neko ../../../backend/temploc2.n -macros macros.mtt -output ../tmp/ *.mtt */*.mtt */*/*.mtt

WORKDIR /srv
USER root
RUN echo "Europe/Paris" > /etc/timezone

# healthcheck
HEALTHCHECK --interval=30s --timeout=5s --retries=5 CMD curl -fsS http://127.0.0.1/ || exit 1

ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]
