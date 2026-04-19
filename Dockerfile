FROM php:8.3-cli-alpine

RUN apk add --no-cache git unzip \
 && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
 && composer global require --no-interaction --prefer-dist ahmedanbar/devguard:^0.1 \
 && ln -s /root/.composer/vendor/bin/devguard /usr/local/bin/devguard

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
