FROM composer:2

# composer:2 ships PHP 8.x + composer + bash + mbstring on Alpine.
# Install DevGuard globally and link its bin onto PATH.
RUN composer global require --no-interaction --prefer-dist ahmedanbar/devguard:^0.1 \
 && ln -s /tmp/vendor/bin/devguard /usr/local/bin/devguard

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
