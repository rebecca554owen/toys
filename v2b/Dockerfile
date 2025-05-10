FROM composer as composer

COPY database/ /app/database/
COPY composer.json /app/

RUN set -x ; cd /app \
      && composer install \
           --ignore-platform-reqs \
           --no-interaction \
           --no-plugins \
           --no-scripts \
           --prefer-dist

FROM php:8.0-fpm-alpine as final

RUN apk add supervisor autoconf g++ make openssl-dev tzdata libcap \
    && rm -rf /var/lib/apt/lists/*
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && docker-php-ext-install mysqli pdo_mysql sockets fileinfo bcmath pcntl \
    && pecl install redis && docker-php-ext-enable redis

ENV TZ=Asia/Shanghai
RUN ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

RUN curl --silent --show-error --fail --location \
    --header "Accept: application/tar+gzip, application/x-gzip, application/octet-stream" \
    -o - "https://github.com/caddyserver/caddy/releases/download/v2.7.6/caddy_2.7.6_linux_amd64.tar.gz" \
    | tar --no-same-owner -C /usr/bin/ -xz caddy \
    && chmod 0755 /usr/bin/caddy \
    && setcap cap_net_bind_service=+ep `readlink -f /usr/bin/caddy` \
    && /usr/bin/caddy version

COPY ./Caddyfile /etc/caddy/Caddyfile
COPY ./supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY ./crontabs/www /var/crontab/www
RUN /usr/bin/crontab /var/crontab/www

VOLUME ["/www"]

WORKDIR /www

COPY . /www
COPY ./.env.example /www/
COPY --from=composer /app/vendor/ /www/vendor/
RUN chown -R www-data:www-data /www && chmod -R 777 /www

USER www-data

EXPOSE 80 443

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]