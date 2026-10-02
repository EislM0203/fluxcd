#!/bin/sh
# before-starting hook (runs as www-data after install/upgrade).
# Kept out of config/ at mount time: the image only seeds its default
# config files (redis, reverse-proxy, apps...) into an EMPTY config dir.
set -eu
cp /nextcloud-custom/custom.config.php /var/www/html/config/custom.config.php
