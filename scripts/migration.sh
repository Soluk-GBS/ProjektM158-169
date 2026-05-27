#!/bin/bash
# =======================================================
# migration.sh – Moodle Migration (bare metal → Docker)
# CloudForge AG | Modul 158/169 | GBS St.Gallen
#
# Voraussetzungen:
#   - SSH-Zugriff auf VM (Ubuntu 22.04)
#   - Docker + Docker Compose installiert
#   - sudo-Rechte
#   - .env im Projektroot vorhanden
#
# Ausführen: bash scripts/migration.sh
# =======================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
step() { echo -e "\n${GREEN}=== $1 ===${NC}"; }
info() { echo -e "${YELLOW}>>> $1${NC}"; }
err()  { echo -e "${RED}!!! FEHLER: $1${NC}"; exit 1; }

# .env laden
[ -f "$PROJECT_DIR/.env" ] || err ".env fehlt! cp .env.example .env && nano .env"
export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)

# -------------------------------------------------------
# Einstellungen anpassen falls nötig
# -------------------------------------------------------
OLD_DB_NAME="moodle"
OLD_MOODLE_DATA="/var/moodledata"
OLD_MOODLE_CONFIG="/var/www/html/moodle/config.php"
DUMP_ALT="$PROJECT_DIR/db/dump_alt.sql"
DUMP_UPGRADED="$PROJECT_DIR/db/dump_migriert.sql"
MOODLEDATA_TMP="/tmp/moodledata_migration"

mkdir -p "$PROJECT_DIR/db"

# -------------------------------------------------------
step "SCHRITT 1: Datenbank-Dump der alten Instanz erstellen"
# -------------------------------------------------------
info "Erstelle mysqldump von: $OLD_DB_NAME"
sudo mysqldump --single-transaction "$OLD_DB_NAME" > "$DUMP_ALT"
info "✅ Dump: $DUMP_ALT ($(du -sh "$DUMP_ALT" | cut -f1))"

# -------------------------------------------------------
step "SCHRITT 2: moodledata sichern"
# -------------------------------------------------------
info "Kopiere $OLD_MOODLE_DATA → db/moodledata_backup/"
sudo cp -r "$OLD_MOODLE_DATA" "$PROJECT_DIR/db/moodledata_backup"
info "✅ moodledata gesichert"

# -------------------------------------------------------
step "SCHRITT 3: Schrittweises DB-Schema-Upgrade (3.x → 4.5)"
# Direkt von 3.10 auf 4.5+ nicht möglich – Zwischenstufen nötig.
# Moodle-Quellcode wird via git clone geholt (kein Download).
# -------------------------------------------------------
mkdir -p "$MOODLEDATA_TMP" && chmod 0777 "$MOODLEDATA_TMP"
sudo cp -r "$OLD_MOODLE_DATA/." "$MOODLEDATA_TMP/"

info "Erstelle temporäres Docker-Netzwerk..."
docker network create moodle_upgrade_net 2>/dev/null || true

info "Starte temporären MariaDB-Container..."
docker rm -f moodle_upgrade_db 2>/dev/null || true
docker run -d \
    --name moodle_upgrade_db \
    --network moodle_upgrade_net \
    -e MARIADB_ROOT_PASSWORD=upgradepass \
    -e MARIADB_DATABASE="$OLD_DB_NAME" \
    -e MARIADB_USER=moodle \
    -e MARIADB_PASSWORD=upgradepass \
    mariadb:10.6

info "Warte auf temporäre MariaDB (30s)..."
sleep 30

info "Importiere alten Dump..."
docker exec -i moodle_upgrade_db mariadb \
    -uroot -pupgradepass "$OLD_DB_NAME" < "$DUMP_ALT"

# -------
# Hilfsfunktion: eine Moodle-Version via Git klonen + CLI-Upgrade
# -------
upgrade_step() {
    local VERSION=$1   # z.B. "4.1"
    local PHP_VER=$2   # z.B. "8.0"
    local BRANCH=$3    # z.B. "MOODLE_401_STABLE"

    info "Upgrade auf Moodle $VERSION (Branch $BRANCH, PHP $PHP_VER)..."
    git clone --depth 1 --branch "$BRANCH" \
        https://github.com/moodle/moodle.git /tmp/moodle_upgrade 2>/dev/null
    cp "$SCRIPT_DIR/config_migration.php" /tmp/moodle_upgrade/config.php
    chmod -R 0777 /tmp/moodle_upgrade

    docker run --rm \
        --network moodle_upgrade_net \
        -v /tmp/moodle_upgrade:/var/www/html/moodle \
        -v "$MOODLEDATA_TMP":/var/moodledata \
        -e MOODLE_DB_HOST=moodle_upgrade_db \
        -e MOODLE_DB_NAME="$OLD_DB_NAME" \
        -e MOODLE_DB_USER=moodle \
        -e MOODLE_DB_PASS=upgradepass \
        moodlehq/moodle-php-apache:"$PHP_VER" \
        su -s /bin/bash www-data -c \
        "php /var/www/html/moodle/admin/cli/upgrade.php --non-interactive"

    rm -rf /tmp/moodle_upgrade
    info "✅ Upgrade auf $VERSION abgeschlossen"
}

# Upgrade-Pfad: 3.10 → 4.1 → 4.4 → 4.5
upgrade_step "4.1" "8.0" "MOODLE_401_STABLE"
upgrade_step "4.4" "8.1" "MOODLE_404_STABLE"
upgrade_step "4.5" "8.3" "MOODLE_405_STABLE"

info "Exportiere migrierten Dump..."
docker exec moodle_upgrade_db mysqldump \
    -uroot -pupgradepass "$OLD_DB_NAME" > "$DUMP_UPGRADED"

info "Bereinige temporäre Upgrade-Umgebung..."
docker stop moodle_upgrade_db && docker rm moodle_upgrade_db
docker network rm moodle_upgrade_net 2>/dev/null || true
rm -rf "$MOODLEDATA_TMP"

# -------------------------------------------------------
step "SCHRITT 4: Alte Apache-Instanz auf Port 8080 umleiten (NFA-02)"
# -------------------------------------------------------
info "Stoppe Apache..."
sudo systemctl stop apache2

info "Ändere Apache-Port 80 → 8080..."
sudo sed -i 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf

# Alle enabled vhosts auf Port 8080 umstellen
for f in /etc/apache2/sites-enabled/*.conf; do
    sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' "$f"
done

info "Passe alte Moodle config.php auf Port 8080 an..."
if sudo grep -q "localhost'" "$OLD_MOODLE_CONFIG" 2>/dev/null; then
    sudo sed -i "s|'http://localhost'|'http://localhost:8080'|g" "$OLD_MOODLE_CONFIG"
elif sudo grep -q 'localhost"' "$OLD_MOODLE_CONFIG" 2>/dev/null; then
    sudo sed -i 's|"http://localhost"|"http://localhost:8080"|g' "$OLD_MOODLE_CONFIG"
fi

info "Starte Apache neu..."
sudo systemctl start apache2

# -------------------------------------------------------
step "SCHRITT 5: Produktive Docker-Instanz starten"
# -------------------------------------------------------
cd "$PROJECT_DIR"

info "Starte MariaDB-Container..."
docker compose up -d moodle-db
info "Warte auf Healthcheck (35s)..."
sleep 35

info "Importiere migrierten Dump in produktive DB..."
docker exec -i moodle-db mariadb \
    -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$DUMP_UPGRADED"

info "Starte neue Moodle-Instanz..."
docker compose up -d moodle-new

info "Kopiere moodledata in Container..."
docker cp "$PROJECT_DIR/db/moodledata_backup/." moodle-new:/var/moodledata/
docker exec moodle-new chown -R www-data:www-data /var/moodledata

info "Letztes CLI-Upgrade im finalen Container..."
docker exec -u www-data moodle-new \
    php /var/www/html/moodle/admin/cli/upgrade.php --non-interactive || true

# -------------------------------------------------------
step "SCHRITT 6: Veraltet-Banner auf alte Instanz (AP-05)"
# -------------------------------------------------------
bash "$SCRIPT_DIR/add-banner.sh"

# -------------------------------------------------------
step "MIGRATION ERFOLGREICH ABGESCHLOSSEN"
# -------------------------------------------------------
echo ""
echo -e "${GREEN}✅ Neue Moodle-Instanz (Docker):  http://localhost${NC}"
echo -e "${GREEN}✅ Alte Moodle-Instanz (Apache):   http://localhost:8080 (mit Banner)${NC}"
echo ""
echo "→ Nächster Schritt: Testfälle T1–T7 durchführen (AP-06)"
echo "  bash scripts/run-tests.sh"
