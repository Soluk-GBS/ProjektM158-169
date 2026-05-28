<div align="center">

# Moodle Migration

**CloudForge AG** · Modul 158/169 · GBS St.Gallen · 2026

| | |
|---|---|
| **Team** | Luka Aurelius Sola (PL) · Leandro Graf (PR) · Stefan Kauflin (TA) |
| **Auftraggeber** | Herr Oliver Lux · GBS St.Gallen |
| **Methode** | HERMES |
| **Ziel** | Moodle 3.10 → 5.0 als Docker-Container |

</div>

---

## Abnahme – Anleitung für Herrn Lux

> **Voraussetzung:** Ubuntu 22.04 LTS VM · sudo-Rechte · Internetverbindung

**Schritt 1 – Token einrichten (einmalig):**
```bash
git config --global url."https://x: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@github.com/".insteadOf "https://github.com/"
```

**Schritt 2 – Migration starten:**
```bash
git clone https://x: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@github.com/Soluk-GBS/ProjektM158-169.git && cd ProjektM158-169 && bash setup.sh
```

> Das Script fragt einmalig nach dem **sudo-Passwort** der VM (vmadmin).  
> Das Passwort ist: `Riethuesli>12345`  
> Das Script läuft danach ~15–20 Minuten vollautomatisch durch.

**Schritt 3 – Web-Upgrade abschliessen:**

Nach dem Script im Browser `http://localhost` öffnen.  
Es erscheint eine Upgrade-Seite — dort auf **Continue** klicken und den Anweisungen folgen bis Moodle fertig ist.

---

## Nach dem Setup im Browser testen

| | |
|---|---|
| Neue Instanz | `http://localhost` |
| Alte Instanz | `http://localhost:8080` (mit Warnbanner) |
| Login | Benutzer: `vmadmin` · Passwort: `Riethuesli>12345` |

---

## Testfälle T1–T7

| Nr. | Test | Erwartetes Ergebnis |
|---|---|---|
| T1 | `http://localhost` aufrufen | Moodle 5.0 Startseite lädt |
| T2 | `http://localhost:8080` aufrufen | Alte Startseite + roter Warnbanner |
| T3 | Beide URLs gleichzeitig öffnen | Beide antworten ohne Konflikt |
| T4 | Mit `vmadmin` einloggen | Login erfolgreich |
| T5 | Kurse prüfen | Modul 305 + Modul 301 vorhanden |
| T6 | `docker compose ps` im Terminal | Beide Container laufen (Up/healthy) |
| T7 | GitHub Repository prüfen | Alle Dateien vorhanden, keine Passwörter |

---

## Projektstruktur

```
ProjektM158-169/
├── moodle/
│   ├── Dockerfile           ← eigenes Image (FA-01)
│   ├── moodle.conf          ← Apache VirtualHost
│   └── config.php           ← Moodle-Konfiguration
├── scripts/
│   ├── setup.sh             ← Haupt-Script
│   ├── add-banner.sh        ← Warnbanner (NFA-02)
│   ├── recover_upgrade.sh   ← Notfall-Script falls DB-Upgrade fehlschlägt
│   └── config_migration.php
├── docker-compose.yml
├── .env.example
├── .gitignore
└── README.md
```
