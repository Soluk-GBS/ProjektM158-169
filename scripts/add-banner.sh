#!/bin/bash
# =======================================================
# add-banner.sh – Veraltet-Banner auf alte Moodle-Instanz
# NFA-02: Alte Instanz muss klar als veraltet erkennbar sein
# AP-05: Leandro Graf (PR) zuständig
# =======================================================

OLD_DB="moodle"

BANNER='<div style="background:#cc0000;color:#ffffff;padding:16px;text-align:center;font-size:15px;font-weight:bold;font-family:sans-serif;">&#9888; ACHTUNG: Diese Moodle-Instanz l&#228;uft auf Version 3.10 (End of Life seit Oktober 2022). Es werden keine Sicherheits-Updates mehr eingespielt. Bitte die neue Instanz unter <a href="http://localhost" style="color:#ffe000;">http://localhost</a> verwenden. &#9888;</div>'

echo "Füge Warnbanner zur alten Moodle-Instanz hinzu..."

sudo mysql "$OLD_DB" <<EOF
INSERT INTO mdl_config (name, value)
  VALUES ('additionalhtmltopofbody', '$BANNER')
  ON DUPLICATE KEY UPDATE value = '$BANNER';
EOF

# Cache leeren damit der Banner sofort sichtbar ist
if [ -d "/var/moodledata/cache" ]; then
    sudo rm -rf /var/moodledata/cache/*
    echo "Cache geleert."
fi

echo "✅ Banner gesetzt. Alte Instanz unter http://localhost:8080 prüfen."
