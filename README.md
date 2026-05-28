<div align="center">

![header](https://capsule-render.vercel.app/api?type=waving&color=3B82F6&height=120&width=1500&section=header)

[![Typing SVG](https://readme-typing-svg.demolab.com?font=Fira+Code&size=28&pause=1000&color=3B82F6&center=true&vCenter=true&width=600&lines=ProjektM158-169;Moodle+Migration+%F0%9F%90%B3;GBS+St.Gallen)](https://git.io/typing-svg)

</div>

<div align="center">

> Migration einer veralteten Moodle-Instanz auf die aktuelle Version als Docker-Container.

**Modul 158/169 – GBS St.Gallen**

</div>

---

## 👥 Team

| Name | Rolle |
|---|---|
| [Luka Sola](https://github.com/luka-sola) | Projektleiter |
| [Leandro Graf](https://github.com/Leandro-gbs) | Protokollführer |
| [Stefan Kauflin](https://github.com/MrKringel76)| Technischer Analyst |

---

## 📁 Inhalt

<!-- TREE_START -->
```
.
├── README.md
├── docker-compose.yml
├── miniprojekt
│   ├── Leandro's Miniprojekt
│   │   ├── README.md
│   │   └── miniprojekt.zip
│   ├── Luka's Miniprojekt
│   │   ├── README.md
│   │   └── m169-miniprojekt.zip
│   └── Stefan's Miniprojekt
│       └── README.md
├── moodle
│   ├── Dockerfile
│   ├── config.php
│   └── moodle.conf
├── scripts
│   ├── add-banner.sh
│   ├── config_migration.php
│   └── migration.sh
└── setup.sh
```
<!-- TREE_END -->


## ▶️ Abnahme – Anleitung für Herrn Lux

> **Voraussetzung:** Ubuntu 22.04 LTS VM · sudo-Rechte · Internetverbindung

**Schritt 1 – Token einrichten (einmalig):**
```bash
git config --global url."https://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@github.com/Soluk-GBS/ProjektM158-169.git".insteadOf "https://github.com/"
```

**Schritt 2 – Migration starten:**
```bash
git clone https://x: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@github.com/Soluk-GBS/ProjektM158-169.git && cd ProjektM158-169 && bash setup.sh
```

Das Script läuft ~15–20 Minuten automatisch durch. Kein weiterer Eingriff nötig.

### Nach dem Setup im Browser testen

| | |
|---|---|
| Neue Instanz | `http://localhost` |
| Alte Instanz | `http://localhost:8080` |
| Login | Benutzer: `vmadmin` · Passwort: `Riethuesli>12345` |

---

<div align="center">

![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Moodle](https://img.shields.io/badge/Moodle-F98012?style=for-the-badge&logo=moodle&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)

![footer](https://capsule-render.vercel.app/api?type=waving&color=3B82F6&height=80&width=1500&section=footer)

</div>
