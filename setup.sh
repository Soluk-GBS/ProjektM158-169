#!/bin/bash
# =======================================================
#  setup.sh – Moodle Migration | CloudForge AG
#  Modul 158/169 | GBS St.Gallen | 2026
#    bash setup.sh
# =======================================================

set -e

C_GREEN='\033[0;32m'; C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'; C_RED='\033[0;31m'
C_BOLD='\033[1m'; C_NC='\033[0m'

REPO_URL="https://github.com/Soluk-GBS/ProjektM158-169.git"
REPO_DIR="$HOME/ProjektM158-169"

step() { echo -e "\n${C_CYAN}${C_BOLD}━━━ $1 ━━━${C_NC}"; }
ok()   { echo -e "  ${C_GREEN}✔ $1${C_NC}"; }
info() { echo -e "  ${C_YELLOW}→ $1${C_NC}"; }
err()  { echo -e "\n${C_RED}✘ FEHLER: $1${C_NC}\n"; exit 1; }

# sudo-Wrapper
S() { echo "$SUDO_PASS" | sudo -S "$@" 2>/dev/null; }

# -------------------------------------------------------
clear
echo -e "${C_CYAN}${C_BOLD}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   Moodle Migration Setup · CloudForge AG    ║"
echo "  ║   Modul 158/169 · GBS St.Gallen · 2026      ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${C_NC}"
echo "  Vollautomatische Migration – kein Eingriff nötig."
echo ""

# -------------------------------------------------------
step "SCHRITT 0 · Sudo-Passwort prüfen"
# -------------------------------------------------------

# .env laden falls schon vorhanden
ENV_FILE=""
[ -f "$REPO_DIR/.env" ] && ENV_FILE="$REPO_DIR/.env"
[ -f ".env" ]           && ENV_FILE=".env"
[ -n "$ENV_FILE" ] && { set -a; source "$ENV_FILE"; set +a; } 2>/dev/null || true

# Passwort prüfen – falls falsch oder leer: nachfragen
check_sudo() {
    echo "$SUDO_PASS" | sudo -S true 2>/dev/null
}

if check_sudo 2>/dev/null; then
    ok "Sudo-Passwort korrekt (aus .env)"
else
    echo -e "  ${C_YELLOW}Sudo-Passwort nicht in .env oder falsch.${C_NC}"
    while true; do
        read -s -p "  → Sudo-Passwort eingeben: " SUDO_PASS
        echo ""
        if echo "$SUDO_PASS" | sudo -S true 2>/dev/null; then
            ok "Sudo-Passwort korrekt"
            break
        else
            echo -e "  ${C_RED}Falsches Passwort, nochmal versuchen.${C_NC}"
        fi
    done
fi

# -------------------------------------------------------
step "SCHRITT 1 · Abhängigkeiten"
# -------------------------------------------------------
command -v git    &>/dev/null || { S apt-get update -qq && S apt-get install -y -qq git; }
command -v docker &>/dev/null || { curl -fsSL https://get.docker.com | S sh; S usermod -aG docker "$USER"; }
docker compose version &>/dev/null 2>&1 || S apt-get install -y -qq docker-compose-plugin
ok "Git:    $(git --version)"
ok "Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"

# -------------------------------------------------------
step "SCHRITT 2 · Repository"
# -------------------------------------------------------
if [ -d "$REPO_DIR/.git" ]; then
    git -C "$REPO_DIR" pull --quiet && ok "Repository aktuell"
else
    git clone "$REPO_URL" "$REPO_DIR" && ok "Repository geklont"
fi
cd "$REPO_DIR"

# -------------------------------------------------------
step "SCHRITT 3 · .env erstellen"
# -------------------------------------------------------
if [ ! -f ".env" ]; then
cat > .env << EOF
# Linux Sudo-Passwort der VM
SUDO_PASS=${SUDO_PASS}

# Datenbank-Passwörter für neue Moodle-Instanz
DB_ROOT_PASS=MoodleRoot2026!
DB_NAME=moodle
DB_USER=moodle
DB_PASS=MoodleUser2026!
EOF
    ok ".env erstellt (mit Sudo-Passwort)"
else
    # SUDO_PASS in bestehende .env eintragen falls fehlt
    grep -q "^SUDO_PASS=" .env || echo "SUDO_PASS=${SUDO_PASS}" >> .env
    ok ".env bereits vorhanden"
fi
set -a; source .env; set +a

# -------------------------------------------------------
step "SCHRITT 4 · Alte Moodle-Installation finden"
# -------------------------------------------------------
OLD_MOODLE_DIR=""
for candidate in /var/www/html/moodle /var/www/html /var/www/moodle /opt/moodle; do
    if S test -f "$candidate/config.php" 2>/dev/null && \
       S grep -q "moodle" "$candidate/config.php" 2>/dev/null; then
        OLD_MOODLE_DIR="$candidate"
        break
    fi
done
[ -n "$OLD_MOODLE_DIR" ] || err "Moodle nicht gefunden."
ok "Moodle: $OLD_MOODLE_DIR"

OLD_MOODLE_DATA=$(S grep -oP "dataroot\s*=\s*['\"]?\K[^'\";\s]+" "$OLD_MOODLE_DIR/config.php" 2>/dev/null || true)
if [ -z "$OLD_MOODLE_DATA" ] || ! S test -d "$OLD_MOODLE_DATA"; then
    for candidate in /var/www/moodledata /var/moodledata /var/www/html/moodledata; do
        S test -d "$candidate" 2>/dev/null && OLD_MOODLE_DATA="$candidate" && break
    done
fi
[ -n "$OLD_MOODLE_DATA" ] || err "moodledata nicht gefunden."
ok "moodledata: $OLD_MOODLE_DATA"

OLD_DB_NAME=$(S grep -oP "dbname\s*=\s*['\"]?\K[^'\";\s]+" "$OLD_MOODLE_DIR/config.php" 2>/dev/null || echo "moodle")
ok "Datenbank: $OLD_DB_NAME"

# -------------------------------------------------------
step "SCHRITT 5 · Docker-Image bauen"
# -------------------------------------------------------
info "Moodle-Docker-Image wird gebaut (ca. 5–10 Min)..."
docker compose build
ok "Docker-Image gebaut"

# -------------------------------------------------------
step "SCHRITT 6 · Datenbank-Dump erstellen"
# -------------------------------------------------------
mkdir -p db
info "Erstelle mysqldump von: $OLD_DB_NAME"
S mysqldump --single-transaction "$OLD_DB_NAME" > db/dump_alt.sql
ok "Dump: $(du -sh db/dump_alt.sql | cut -f1)"

# -------------------------------------------------------
step "SCHRITT 7 · moodledata sichern"
# -------------------------------------------------------
info "Kopiere $OLD_MOODLE_DATA..."
S rm -rf db/moodledata_backup
S cp -r "$OLD_MOODLE_DATA" db/moodledata_backup
S chmod -R 777 db/moodledata_backup
ok "moodledata gesichert"

# -------------------------------------------------------
step "SCHRITT 8 · Schrittweises DB-Upgrade (3.10 → 4.5)"
# -------------------------------------------------------
MOODLEDATA_TMP="/tmp/moodledata_migration"
S rm -rf "$MOODLEDATA_TMP"
S mkdir -p "$MOODLEDATA_TMP"
S cp -r "$OLD_MOODLE_DATA/." "$MOODLEDATA_TMP/"
S chmod -R 777 "$MOODLEDATA_TMP"

docker network create moodle_upgrade_net 2>/dev/null || true
docker rm -f moodle_upgrade_db 2>/dev/null || true
docker run -d \
    --name moodle_upgrade_db \
    --network moodle_upgrade_net \
    -e MARIADB_ROOT_PASSWORD=upgradepass \
    -e MARIADB_DATABASE="$OLD_DB_NAME" \
    -e MARIADB_USER=moodle \
    -e MARIADB_PASSWORD=upgradepass \
    mariadb:10.6

info "Warte auf MariaDB (30s)..."
sleep 30
docker exec -i moodle_upgrade_db mariadb \
    -uroot -pupgradepass "$OLD_DB_NAME" < db/dump_alt.sql
ok "Dump importiert"

do_upgrade() {
    local VERSION=$1 PHP=$2 BRANCH=$3
    info "Upgrade → Moodle $VERSION..."
    S rm -rf /tmp/moodle_upgrade
    git clone --depth 1 --branch "$BRANCH" \
        https://github.com/moodle/moodle.git /tmp/moodle_upgrade 2>/dev/null
    cp scripts/config_migration.php /tmp/moodle_upgrade/config.php
    S chmod -R 777 /tmp/moodle_upgrade
    docker run --rm \
        --network moodle_upgrade_net \
        -v /tmp/moodle_upgrade:/var/www/html/moodle \
        -v "$MOODLEDATA_TMP":/var/moodledata \
        -e MOODLE_DB_HOST=moodle_upgrade_db \
        -e MOODLE_DB_NAME="$OLD_DB_NAME" \
        -e MOODLE_DB_USER=moodle \
        -e MOODLE_DB_PASS=upgradepass \
        moodlehq/moodle-php-apache:"$PHP" \
        su -s /bin/bash www-data -c \
        "php /var/www/html/moodle/admin/cli/upgrade.php --non-interactive"
    S rm -rf /tmp/moodle_upgrade   # ← sudo rm, da Docker root-Dateien erstellt
    ok "Moodle $VERSION ✔"
}

do_upgrade "4.1" "8.0" "MOODLE_401_STABLE"
do_upgrade "4.4" "8.1" "MOODLE_404_STABLE"
do_upgrade "4.5" "8.3" "MOODLE_405_STABLE"
do_upgrade "5.0" "8.3" "MOODLE_500_STABLE"


info "Exportiere migrierten Dump..."
docker exec moodle_upgrade_db mysqldump \
    -uroot -pupgradepass "$OLD_DB_NAME" > db/dump_migriert.sql
ok "Migrierter Dump: $(du -sh db/dump_migriert.sql | cut -f1)"

docker stop moodle_upgrade_db && docker rm moodle_upgrade_db
docker network rm moodle_upgrade_net 2>/dev/null || true
S rm -rf "$MOODLEDATA_TMP" /tmp/moodle_upgrade

# -------------------------------------------------------
step "SCHRITT 9 · Alte Apache-Instanz → Port 8080"
# -------------------------------------------------------
S systemctl stop apache2
S sed -i 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf
for f in /etc/apache2/sites-enabled/*.conf; do
    [ -f "$f" ] && S sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' "$f"
done
OLD_CFG="$OLD_MOODLE_DIR/config.php"
if S test -f "$OLD_CFG"; then
    S sed -i "s|'http://localhost'|'http://localhost:8080'|g" "$OLD_CFG"
    S sed -i 's|"http://localhost"|"http://localhost:8080"|g' "$OLD_CFG"
fi
S systemctl start apache2
ok "Alte Instanz → Port 8080"

# -------------------------------------------------------
step "SCHRITT 10 · Neue Docker-Instanz starten"
# -------------------------------------------------------
docker compose up -d moodle-db
info "Warte auf Healthcheck (40s)..."
sleep 40
docker exec -i moodle-db mariadb \
    -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < db/dump_migriert.sql
docker compose up -d moodle-new
docker cp db/moodledata_backup/. moodle-new:/var/moodledata/
docker exec moodle-new chown -R www-data:www-data /var/moodledata
docker exec -u www-data moodle-new \
    php /var/www/html/moodle/admin/cli/upgrade.php --non-interactive || true
ok "Neue Instanz → Port 80"

# -------------------------------------------------------
step "SCHRITT 11 · Warnbanner"
# -------------------------------------------------------
bash scripts/add-banner.sh "$OLD_DB_NAME"
ok "Warnbanner gesetzt"

# -------------------------------------------------------
echo ""
echo -e "${C_GREEN}${C_BOLD}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║           Migration abgeschlossen! ✅        ║"
echo "  ╠══════════════════════════════════════════════╣"
echo "  ║  Neue Moodle-Instanz:  http://localhost      ║"
echo "  ║  Alte Moodle-Instanz:  http://localhost:8080 ║"
echo "  ╠══════════════════════════════════════════════╣"
echo "  ║  Nächster Schritt: Testfälle T1–T7 (AP-06)  ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${C_NC}"
