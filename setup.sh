#!/bin/bash
# =======================================================
#  setup.sh – Moodle Migration | CloudForge AG
#  Modul 158/169 | GBS St.Gallen
#
#  Dieses Script macht ALLES automatisch:
#    1. Docker + Git installieren (falls nötig)
#    2. Repository klonen
#    3. .env erstellen
#    4. Docker-Image bauen (Moodle per git clone)
#    5. Alte Instanz auf Port 8080 verschieben
#    6. Daten migrieren (DB-Dump + moodledata)
#    7. Neue Instanz auf Port 80 starten
#    8. Warnbanner auf alte Instanz setzen
#
#  Ausführen (auf der VM, einmalig):
#    curl -fsSL https://raw.githubusercontent.com/Soluk-GBS/ProjektM158-169/main/setup.sh | bash
#  ODER:
#    bash setup.sh
#
#  Voraussetzung: Ubuntu 20.04 / 22.04 LTS, sudo-Rechte
# =======================================================

set -e

# -------------------------------------------------------
# Farben & Hilfsfunktionen
# -------------------------------------------------------
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'
C_RED='\033[0;31m'
C_BOLD='\033[1m'
C_NC='\033[0m'

REPO_URL="https://github.com/Soluk-GBS/ProjektM158-169.git"
REPO_DIR="$HOME/ProjektM158-169"

step()    { echo -e "\n${C_CYAN}${C_BOLD}━━━ $1 ━━━${C_NC}"; }
ok()      { echo -e "  ${C_GREEN}✔ $1${C_NC}"; }
info()    { echo -e "  ${C_YELLOW}→ $1${C_NC}"; }
err()     { echo -e "\n${C_RED}✘ FEHLER: $1${C_NC}\n"; exit 1; }
ask()     { echo -e "  ${C_BOLD}$1${C_NC}"; }

# -------------------------------------------------------
# Banner
# -------------------------------------------------------
clear
echo -e "${C_CYAN}${C_BOLD}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   Moodle Migration Setup · CloudForge AG    ║"
echo "  ║   Modul 158/169 · GBS St.Gallen · 2026      ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${C_NC}"
echo "  Dieses Script richtet die komplette Moodle-Migration"
echo "  automatisch ein. Dauer: ca. 10–20 Minuten."
echo ""

# -------------------------------------------------------
# Sudo-Check
# -------------------------------------------------------
if ! sudo -n true 2>/dev/null; then
    info "Sudo-Passwort wird benötigt (einmalig):"
    sudo -v || err "Kein sudo-Zugriff. Script als User mit sudo-Rechten ausführen."
fi

# -------------------------------------------------------
step "SCHRITT 1 · Abhängigkeiten prüfen & installieren"
# -------------------------------------------------------

# Git
if ! command -v git &>/dev/null; then
    info "Git wird installiert..."
    sudo apt-get update -qq && sudo apt-get install -y -qq git
    ok "Git installiert: $(git --version)"
else
    ok "Git vorhanden: $(git --version)"
fi

# Docker
if ! command -v docker &>/dev/null; then
    info "Docker wird installiert..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    ok "Docker installiert"
    info "WICHTIG: Nach dem Script einmal aus- und einloggen (oder 'newgrp docker')."
    USE_SUDO_DOCKER="sudo"
else
    ok "Docker vorhanden: $(docker --version)"
    USE_SUDO_DOCKER=""
fi

# Docker Compose v2
if ! docker compose version &>/dev/null 2>&1; then
    info "Docker Compose v2 wird installiert..."
    sudo apt-get install -y -qq docker-compose-plugin 2>/dev/null || \
    sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose && \
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    ok "Docker Compose installiert"
else
    ok "Docker Compose vorhanden: $(docker compose version)"
fi

# -------------------------------------------------------
step "SCHRITT 2 · Repository klonen"
# -------------------------------------------------------

if [ -d "$REPO_DIR/.git" ]; then
    info "Repository bereits vorhanden, aktualisiere..."
    git -C "$REPO_DIR" pull --quiet
    ok "Repository aktuell: $REPO_DIR"
else
    info "Klone Repository von GitHub..."
    git clone "$REPO_URL" "$REPO_DIR"
    ok "Repository geklont: $REPO_DIR"
fi

cd "$REPO_DIR"

# -------------------------------------------------------
step "SCHRITT 3 · Konfiguration (.env)"
# -------------------------------------------------------

if [ -f ".env" ]; then
    ok ".env bereits vorhanden – wird verwendet."
    export $(grep -v '^#' .env | xargs)
else
    echo ""
    ask "Bitte Datenbankpasswörter festlegen:"
    echo "  (Einfach Enter drücken für Standardwerte)"
    echo ""

    read -p "  DB Root-Passwort    [Standard: MoodleRoot2026!]: " INPUT_ROOT
    read -p "  DB User-Passwort    [Standard: MoodleUser2026!]: " INPUT_PASS
    read -p "  DB Name             [Standard: moodle]:           " INPUT_NAME
    read -p "  DB User             [Standard: moodle]:           " INPUT_USER

    DB_ROOT_PASS="${INPUT_ROOT:-MoodleRoot2026!}"
    DB_PASS="${INPUT_PASS:-MoodleUser2026!}"
    DB_NAME="${INPUT_NAME:-moodle}"
    DB_USER="${INPUT_USER:-moodle}"

    cat > .env << EOF
DB_ROOT_PASS=${DB_ROOT_PASS}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
EOF
    ok ".env erstellt"
    export DB_ROOT_PASS DB_NAME DB_USER DB_PASS
fi

# -------------------------------------------------------
step "SCHRITT 4 · Modus wählen"
# -------------------------------------------------------

echo ""
ask "Was soll gemacht werden?"
echo "  [1] Komplette Migration (alte Moodle-Daten übernehmen)  ← Standard"
echo "  [2] Nur neue Moodle-Instanz aufsetzen (Frischinstall)"
echo ""
read -p "  Auswahl [1/2, Standard=1]: " MODE_INPUT
MODE="${MODE_INPUT:-1}"

# -------------------------------------------------------
step "SCHRITT 5 · Docker-Image bauen"
# -------------------------------------------------------

info "Baue Moodle-Docker-Image (Moodle wird via git geklont)..."
info "Das dauert beim ersten Mal ~5–10 Minuten..."
$USE_SUDO_DOCKER docker compose build --no-cache
ok "Docker-Image erfolgreich gebaut"

# -------------------------------------------------------
# Modus 1: Migration
# -------------------------------------------------------
if [ "$MODE" = "1" ]; then

    step "SCHRITT 6 · Alte Moodle-Instanz konfigurieren"

    # Pfade erfragen
    echo ""
    ask "Pfad zur alten Moodle-Installation?"
    read -p "  [Standard: /var/www/html/moodle]: " INPUT_MOODLE_DIR
    OLD_MOODLE_DIR="${INPUT_MOODLE_DIR:-/var/www/html/moodle}"

    ask "Pfad zum moodledata-Verzeichnis?"
    read -p "  [Standard: /var/moodledata]: " INPUT_MOODLE_DATA
    OLD_MOODLE_DATA="${INPUT_MOODLE_DATA:-/var/moodledata}"

    ask "Name der alten Moodle-Datenbank?"
    read -p "  [Standard: moodle]: " INPUT_OLD_DB
    OLD_DB_NAME="${INPUT_OLD_DB:-moodle}"

    # Pfade prüfen
    [ -d "$OLD_MOODLE_DIR" ]  || err "Moodle-Verzeichnis nicht gefunden: $OLD_MOODLE_DIR"
    [ -d "$OLD_MOODLE_DATA" ] || err "moodledata nicht gefunden: $OLD_MOODLE_DATA"

    mkdir -p db

    # ----
    step "SCHRITT 7 · Datenbank-Dump erstellen"
    # ----
    info "Erstelle mysqldump von: $OLD_DB_NAME"
    sudo mysqldump --single-transaction "$OLD_DB_NAME" > db/dump_alt.sql
    DUMP_SIZE=$(du -sh db/dump_alt.sql | cut -f1)
    ok "Dump erstellt (${DUMP_SIZE}): db/dump_alt.sql"

    # ----
    step "SCHRITT 8 · moodledata sichern"
    # ----
    info "Kopiere moodledata..."
    sudo cp -r "$OLD_MOODLE_DATA" db/moodledata_backup
    ok "moodledata gesichert: db/moodledata_backup/"

    # ----
    step "SCHRITT 9 · Schrittweises DB-Schema-Upgrade (3.10 → 4.5)"
    # ----
    info "Starte temporäre Upgrade-Umgebung..."

    MOODLEDATA_TMP="/tmp/moodledata_migration"
    mkdir -p "$MOODLEDATA_TMP" && chmod 0777 "$MOODLEDATA_TMP"
    sudo cp -r "$OLD_MOODLE_DATA/." "$MOODLEDATA_TMP/"

    $USE_SUDO_DOCKER docker network create moodle_upgrade_net 2>/dev/null || true

    $USE_SUDO_DOCKER docker rm -f moodle_upgrade_db 2>/dev/null || true
    $USE_SUDO_DOCKER docker run -d \
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
    $USE_SUDO_DOCKER docker exec -i moodle_upgrade_db \
        mariadb -uroot -pupgradepass "$OLD_DB_NAME" < db/dump_alt.sql
    ok "Dump importiert"

    # Upgrade-Funktion
    do_upgrade() {
        local VERSION=$1 PHP=$2 BRANCH=$3
        info "Upgrade: Moodle $VERSION (PHP $PHP)..."
        rm -rf /tmp/moodle_upgrade
        git clone --depth 1 --branch "$BRANCH" \
            https://github.com/moodle/moodle.git /tmp/moodle_upgrade 2>/dev/null
        cp scripts/config_migration.php /tmp/moodle_upgrade/config.php
        chmod -R 0777 /tmp/moodle_upgrade
        $USE_SUDO_DOCKER docker run --rm \
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
        rm -rf /tmp/moodle_upgrade
        ok "Upgrade auf $VERSION abgeschlossen"
    }

    do_upgrade "4.1" "8.0" "MOODLE_401_STABLE"
    do_upgrade "4.4" "8.1" "MOODLE_404_STABLE"
    do_upgrade "4.5" "8.3" "MOODLE_405_STABLE"

    info "Exportiere migrierten Dump..."
    $USE_SUDO_DOCKER docker exec moodle_upgrade_db \
        mysqldump -uroot -pupgradepass "$OLD_DB_NAME" > db/dump_migriert.sql
    ok "Migrierter Dump: db/dump_migriert.sql ($(du -sh db/dump_migriert.sql | cut -f1))"

    info "Bereinige temporäre Upgrade-Umgebung..."
    $USE_SUDO_DOCKER docker stop moodle_upgrade_db
    $USE_SUDO_DOCKER docker rm moodle_upgrade_db
    $USE_SUDO_DOCKER docker network rm moodle_upgrade_net 2>/dev/null || true
    rm -rf "$MOODLEDATA_TMP" /tmp/moodle_upgrade

    # ----
    step "SCHRITT 10 · Alte Apache-Instanz auf Port 8080"
    # ----
    info "Stoppe Apache..."
    sudo systemctl stop apache2

    info "Ändere Apache-Port 80 → 8080..."
    sudo sed -i 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf
    for f in /etc/apache2/sites-enabled/*.conf; do
        [ -f "$f" ] && sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' "$f"
    done

    info "Passe alte config.php auf Port 8080 an..."
    OLD_CFG="$OLD_MOODLE_DIR/config.php"
    if [ -f "$OLD_CFG" ]; then
        sudo sed -i "s|'http://localhost'|'http://localhost:8080'|g" "$OLD_CFG"
        sudo sed -i 's|"http://localhost"|"http://localhost:8080"|g' "$OLD_CFG"
    fi

    sudo systemctl start apache2
    ok "Alte Instanz läuft auf Port 8080"

    # ----
    step "SCHRITT 11 · Neue Docker-Instanz starten & Daten importieren"
    # ----
    info "Starte MariaDB..."
    $USE_SUDO_DOCKER docker compose up -d moodle-db
    info "Warte auf Healthcheck (40s)..."
    sleep 40

    info "Importiere migrierten Dump in produktive DB..."
    $USE_SUDO_DOCKER docker exec -i moodle-db \
        mariadb -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < db/dump_migriert.sql

    info "Starte neue Moodle-Instanz..."
    $USE_SUDO_DOCKER docker compose up -d moodle-new

    info "Kopiere moodledata in Container-Volume..."
    $USE_SUDO_DOCKER docker cp db/moodledata_backup/. moodle-new:/var/moodledata/
    $USE_SUDO_DOCKER docker exec moodle-new chown -R www-data:www-data /var/moodledata

    info "Finales Moodle-Upgrade im Container..."
    $USE_SUDO_DOCKER docker exec -u www-data moodle-new \
        php /var/www/html/moodle/admin/cli/upgrade.php --non-interactive || true
    ok "Daten erfolgreich migriert"

    # ----
    step "SCHRITT 12 · Warnbanner auf alte Instanz"
    # ----
    bash scripts/add-banner.sh
    ok "Warnbanner gesetzt"

# -------------------------------------------------------
# Modus 2: Frischinstall
# -------------------------------------------------------
else
    step "SCHRITT 6 · Neue Moodle-Instanz starten (Frischinstall)"
    $USE_SUDO_DOCKER docker compose up -d
    ok "Container gestartet"
    info "Moodle-Ersteinrichtung unter http://localhost aufrufen."
fi

# -------------------------------------------------------
step "FERTIG"
# -------------------------------------------------------
echo ""
echo -e "${C_GREEN}${C_BOLD}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║           Setup abgeschlossen! ✅            ║"
echo "  ╠══════════════════════════════════════════════╣"
if [ "$MODE" = "1" ]; then
echo "  ║  Neue Moodle-Instanz:  http://localhost      ║"
echo "  ║  Alte Moodle-Instanz:  http://localhost:8080 ║"
else
echo "  ║  Moodle:               http://localhost      ║"
fi
echo "  ╠══════════════════════════════════════════════╣"
echo "  ║  Nächster Schritt: Testfälle T1–T7 (AP-06)  ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${C_NC}"

if [ -n "$USE_SUDO_DOCKER" ]; then
    echo -e "  ${C_YELLOW}Hinweis: Bitte einmal aus- und einloggen,${C_NC}"
    echo -e "  ${C_YELLOW}damit Docker ohne sudo nutzbar ist.${C_NC}\n"
fi
