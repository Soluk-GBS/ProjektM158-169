#!/bin/bash
# =======================================================
# add-banner.sh – Warnbanner auf alte Moodle-Instanz
# NFA-02: Banner immer sichtbar auf ALLEN Seiten
# =======================================================

OLD_DB="${1:-moodle}"

# position:fixed → immer sichtbar, egal auf welchem Reiter
BANNER='<div style="position:fixed;top:0;left:0;width:100%;background:#cc0000;color:#ffffff;padding:12px 16px;text-align:center;font-size:14px;font-weight:bold;font-family:sans-serif;z-index:99999;box-sizing:border-box;">&#9888; ACHTUNG: Diese Moodle-Instanz läuft auf Version 3.10 (End of Life seit Oktober 2022). Es werden keine Sicherheits-Updates mehr eingespielt. Bitte die neue Instanz unter <a href="http://localhost" style="color:#ffe000;text-decoration:underline;">http://localhost</a> verwenden. &#9888;</div><div style="height:45px;"></div>'

echo "→ Setze Warnbanner auf alte Moodle-Instanz (DB: $OLD_DB)..."

sudo mysql "$OLD_DB" <<SQL
INSERT INTO mdl_config (name, value)
  VALUES ('additionalhtmltopofbody', '$BANNER')
  ON DUPLICATE KEY UPDATE value = '$BANNER';
SQL

sudo rm -rf /var/www/moodledata/cache/* 2>/dev/null || true
sudo rm -rf /var/moodledata/cache/* 2>/dev/null || true

echo "✔ Banner gesetzt – sichtbar auf allen Seiten unter http://localhost:8080"
