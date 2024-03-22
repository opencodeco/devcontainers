#!/usr/bin/env bash
set -e
curl -sSLf \
    -o /usr/local/bin/install-php-extensions \
    https://github.com/mlocati/docker-php-extension-installer/releases/download/2.2.5/install-php-extensions
chmod +x /usr/local/bin/install-php-extensions
install-php-extensions "$EXTENSIONS"
