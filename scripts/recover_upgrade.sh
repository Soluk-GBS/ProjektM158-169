#!/bin/bash
# =======================================================
# recover_upgrade.sh – DB-Upgrade direkt gegen laufende DB
# =======================================================
set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✔ $1${NC}"; }
info() { echo -e "  ${YELLOW}→ $1${NC}"; }

set -a; source .env; set +a

# Netzwerk ermitteln
NETWORK=$(docker inspect moodle-new --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}' 2>/dev/null | head -1)
info "Netzwerk: $NETWORK"

# moodledata-Rechte im Volume fixen
info "Fixe moodledata-Berechtigungen..."
docker exec moodle-new chown -R www-data:www-data /var/moodledata
docker exec moodle-new chmod -R 777 /var/moodledata
ok "Berechtigungen gesetzt"

do_upgrade() {
    local VERSION=$1 PHP=$2 URL=$3
    info "Upgrade → Moodle $VERSION..."
    curl -fsSL "$URL" -o /tmp/mu.tgz
    rm -rf /tmp/mu && mkdir -p /tmp/mu
    tar -xzf /tmp/mu.tgz -C /tmp/mu --strip-components=1
    cp scripts/config_migration.php /tmp/mu/config.php
    chmod -R 777 /tmp/mu

    set +e
    docker run --rm \
        --network "$NETWORK" \
        -v /tmp/mu:/var/www/html/moodle \
        -v projektm158-169_moodle_data:/var/moodledata \
        -e MOODLE_DB_HOST=moodle-db \
        -e MOODLE_DB_NAME="$DB_NAME" \
        -e MOODLE_DB_USER="$DB_USER" \
        -e MOODLE_DB_PASS="$DB_PASS" \
        php:"$PHP"-apache \
        bash -c "docker-php-ext-install mysqli pdo_mysql intl zip mbstring > /dev/null 2>&1; echo max_input_vars=5000 >> /usr/local/etc/php/php.ini; chown -R www-data:www-data /var/moodledata; su -s /bin/bash www-data -c 'php /var/www/html/moodle/admin/cli/upgrade.php --non-interactive'"
    set -e
    sudo rm -rf /tmp/mu /tmp/mu.tgz
    ok "Moodle $VERSION ✔"
}

do_upgrade "4.1" "8.0" "https://packaging.moodle.org/stable401/moodle-latest-401.tgz"
do_upgrade "4.4" "8.1" "https://packaging.moodle.org/stable404/moodle-latest-404.tgz"
do_upgrade "4.5" "8.3" "https://packaging.moodle.org/stable405/moodle-latest-405.tgz"

info "Finales Upgrade in moodle-new Container..."
docker exec -u www-data moodle-new \
    php /var/www/html/moodle/admin/cli/upgrade.php --non-interactive || true

ok "Fertig! http://localhost neu laden."
