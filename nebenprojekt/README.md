# 1. In den Ordner wechseln
cd m169-miniprojekt

# 2. Container bauen & starten
docker compose up -d

# 3. Browser öffnen
http://localhost:8080
```

**Das war's.** Die Website läuft sofort.

---

## Was du für das Video zeigst

1. `docker compose up -d` ausführen → Container startet
2. Browser auf `localhost:8080` → Website läuft
3. `website/index.html` öffnen, z.B. den Hero-Text ändern → Seite neu laden → **Änderung ist sofort sichtbar** (weil Volume-Mount)
4. `docker compose logs -f` → Logs laufen live mit
5. `cat logs/access.log` → Logs sind lokal auf dem PC

---

## Dateistruktur
```
m169-miniprojekt/
├── Dockerfile          ← eigenes NGINX-Image (Alpine)
├── docker-compose.yml  ← Service + Volume + Healthcheck
├── nginx.conf          ← NGINX-Konfiguration
├── website/            ← HTML/CSS/JS (via Volume = live änderbar)
├── logs/               ← NGINX-Logs landen hier lokal
└── README.md
