# Anleitung – Projekt replizieren
 
## Voraussetzungen
 
- Windows 10/11
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installiert
- [Git](https://git-scm.com/download/win) installiert
 
---
 
## Schritt 1 – Docker Desktop starten
 
1. Docker Desktop öffnen
2. Warten bis unten links **grün** steht → "Engine running"
3. Erst dann weitermachen
 
---
 
## Schritt 2 – Repository klonen
 
PowerShell oder CMD öffnen:
 
```powershell
git clone https://github.com/<dein-username>/m169-miniprojekt.git
cd m169-miniprojekt
```
 
---
 
## Schritt 3 – Container starten
 
```powershell
docker compose up -d
```
 
Beim ersten Mal lädt Docker das NGINX-Image herunter (~10MB), danach startet der Container.
 
Erwartete Ausgabe:
```
✔ Container m169-webserver  Started
```
 
---
 
## Schritt 4 – Website aufrufen
 
Browser öffnen:
```
http://localhost:8080
```
 
Die Website sollte jetzt laufen ✅
 
---
 
## Schritt 5 – Prüfen ob alles läuft
 
```powershell
docker ps
```
 
Du solltest sehen:
```
CONTAINER ID   IMAGE               STATUS (healthy)   PORTS
xxxxxxxxxxxx   m169-webserver      Up X seconds       0.0.0.0:8080->80/tcp
```
 
---
 
## Live-Änderungen machen
 
Da der `website/`-Ordner als Volume gemountet ist, kannst du Dateien direkt bearbeiten:
 
1. `website/index.html` in VS Code öffnen
2. Änderung machen & speichern
3. Browser neu laden → Änderung sofort sichtbar ✅
 
Kein Neustart des Containers nötig.
 
---
 
## Logs anschauen
 
```powershell
# Live-Logs im Terminal
docker compose logs -f
 
# Lokal gespeicherte Logs
cat logs/access.log
```
 
---
 
## Container stoppen
 
```powershell
docker compose down
```
 
---
