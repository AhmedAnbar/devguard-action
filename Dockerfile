FROM composer:2

# composer:2 ships PHP 8.x + composer + bash + mbstring on Alpine.
#
# IMPORTANT: For 0.x packages, Composer's caret operator pins to the *minor*
# (^0.1 = >=0.1.0 <0.2.0). The first version of this Dockerfile pinned to
# ^0.1, which silently froze the action on v0.1.x for 8 minor releases —
# users of @v1 missed env audit, deps audit, fix command, --html, baseline,
# SARIF, etc. Always OR every supported minor explicitly until DevGuard
# hits 1.0. See lesson #6 in CLAUDE.md.
RUN composer global require --no-interaction --prefer-dist \
        "ahmedanbar/devguard:^0.1 || ^0.2 || ^0.3 || ^0.4 || ^0.5 || ^0.6 || ^0.7 || ^0.8" \
 && ln -s /tmp/vendor/bin/devguard /usr/local/bin/devguard

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
