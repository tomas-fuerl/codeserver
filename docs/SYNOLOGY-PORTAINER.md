# Synology- und Portainer-Installation

Diese Anleitung definiert den öffentlichen Installationsvertrag. Alle Befehle
und Pfade sind zukünftige Betreiberbeispiele mit Platzhaltern. MIG-004 führt
keinen dieser externen Schritte aus und behauptet keinen produktiven
Deploymenterfolg.

## 1. Voraussetzungen

Erforderlich sind:

- eine Synology mit Container Manager beziehungsweise Docker-Unterstützung;
- Portainer mit Berechtigung zum Anlegen eines Git-Stacks;
- eine lokale Shell mit den erforderlichen administrativen Rechten;
- optional ein HTTPS-Reverse-Proxy;
- das öffentlich erreichbare GitHub-Repository erst ab MIG-009;
- ein öffentlich verfügbares, freigegebenes GHCR-Image erst ab MIG-010.

Repository und Image sind in MIG-004 noch nicht veröffentlicht. Die folgenden
Schritte können daher erst nach den genannten Migrationsgates produktiv
ausgeführt werden.

## 2. Lokale Verzeichnisstruktur

Die tatsächlichen Pfade werden vom Betreiber gewählt. Öffentliche Beispiele
verwenden ausschließlich:

| Beispielpfad | Zweck | Erwartete Rechte |
| --- | --- | --- |
| `/example/synology/docker/codeserver` | Persistente Konfiguration, Workspace und Anwendungsdaten | Für die lokal ermittelten `PUID`/`PGID` schreibbar; nicht öffentlich zugänglich |
| `/example/synology/docker/codeserver-secrets` | Geschützte Secret-Ablage | Nur lokales Administrationsmodell; Verzeichnis typischerweise `0700` |
| `/example/synology/docker/codeserver-backups` | Restriktive Backuparchive und Sidecars | Nur Backupadministration; nicht als Container-Mount |
| `/example/synology/docker/codeserver-restore-tests` | Basis für nicht-destruktive Restore-Tests | Nur Administration; strikt getrennt von Config und Secret |

Zukünftige Anlage und Rechtevergabe sind eine `EXTERNAL OPERATOR ACTION`.
Platzhalterbefehle:

```bash
sudo install -d -m 0750 "<CODESERVER_CONFIG_PATH>"
sudo install -d -m 0700 "<CODESERVER_SECRET_ROOT>"
sudo install -d -m 0700 "<CODESERVER_BACKUP_PATH>"
sudo install -d -m 0700 "<CODESERVER_RESTORE_PATH>"
sudo chown "<PUID>:<PGID>" "<CODESERVER_CONFIG_PATH>"
```

Eigentümer und Gruppe der administrativen Verzeichnisse richten sich nach dem
lokalen Synology-Berechtigungsmodell und werden nicht aus öffentlichen
Beispielwerten abgeleitet.

## 3. Secret-Datei

Die lokale Datei heißt exakt `hashed_password`. Sie enthält ausschließlich
einen nicht leeren Argon2-Passwort-Hash ohne zusätzlichen Klartext. Sie wird
niemals in Git aufgenommen und read-only nach
`/run/secrets/hashed_password` gemountet.

Zukünftige Bereitstellung ist eine `EXTERNAL OPERATOR ACTION`. Ein Betreiber
erzeugt den Argon2-Hash mit einem lokal freigegebenen Werkzeug und installiert
ihn ohne Shell-Historien- oder Log-Leak. Nur Platzhalter dürfen in
Beispielbefehlen stehen:

```bash
sudo sh -c 'umask 077; printf "%s" "<ARGON2_HASH>" > "<CODESERVER_SECRET_ROOT>/hashed_password"'
sudo chown "<SECRET_OWNER>:<SECRET_GROUP>" "<CODESERVER_SECRET_ROOT>/hashed_password"
sudo chmod 0600 "<CODESERVER_SECRET_ROOT>/hashed_password"
```

Der Dateiname, Nicht-Leere, Eigentümer, Gruppe und Modus werden geprüft, der
Inhalt jedoch weder angezeigt noch in Nachweise übernommen.

## 4. UID und GID

`PUID` und `PGID` müssen auf der Synology für das Konto ermittelt werden, das
den persistenten Configbaum besitzen soll. Ein zukünftiger lesender
Betreiberbefehl ist:

```bash
id "<SYNOLOGY_ACCOUNT>"
```

Die ausgegebenen numerischen Werte werden mit Eigentümer und Schreibrechten
des Configpfads abgeglichen. `1000:1000` in `.env.example` ist nur ein
öffentliches Beispiel und keine Synology-Annahme.

## 5. Portainer-Git-Stack

Nach MIG-009 und MIG-010 wird ein Stack mit folgenden festen Git-Werten
angelegt:

```text
Repository URL:
https://github.com/tomas-fuerl/codeserver.git

Reference:
main

Compose path:
compose.yaml

GitOps automatic updates:
disabled for initial cutover
```

Die produktiven Werte werden in Portainer gepflegt, nicht in einer
Repository-Environment-Datei:

| Variable | Pflicht | Öffentlicher Beispielwert | Betreiberregel |
| --- | --- | --- | --- |
| `CODESERVER_IMAGE_REPOSITORY` | Nein | `ghcr.io/tomas-fuerl/codeserver` | Öffentlichen Default beibehalten, sofern kein genehmigter Ersatz existiert |
| `CODESERVER_IMAGE_TAG` | Ja | `CHANGE_ME` | Durch eine tatsächlich freigegebene, unveränderliche Version ersetzen; niemals `latest` |
| `CODESERVER_CONTAINER_NAME` | Nein | `codeserver` | Mit Skriptaufrufen konsistent halten |
| `CODESERVER_BIND_ADDRESS` | Nein | `127.0.0.1` | Für diesen Vertrag nicht auf eine externe Adresse ändern |
| `CODESERVER_HOST_PORT` | Nein | `8377` | Freien lokalen TCP-Port wählen und im Reverse Proxy spiegeln |
| `CODESERVER_CONFIG_PATH` | Ja | `/example/synology/docker/codeserver` | Absoluter vorhandener Configpfad |
| `CODESERVER_SECRET_FILE` | Ja | `/example/synology/docker/codeserver-secrets/hashed_password` | Absoluter Pfad zur nicht leeren Datei mit Modus `0600` |
| `CODESERVER_BACKUP_PATH` | Für Backupbetrieb | `/example/synology/docker/codeserver-backups` | Nicht als Container-Mount verwenden |
| `CODESERVER_RESTORE_PATH` | Für Restore-Tests | `/example/synology/docker/codeserver-restore-tests` | Restoreziele nur strikt darunter wählen |
| `PUID` | Ja | `1000` | Lokal ermittelte numerische UID |
| `PGID` | Ja | `1000` | Lokal ermittelte numerische GID |
| `TZ` | Nein | `Europe/Berlin` | Gültigen lokalen IANA-Zeitzonennamen wählen |
| `PROXY_DOMAIN` | Nein | `codeserver.example.com` | Reale Domain nur lokal in Portainer; ohne Schema oder Pfad |

Details und die Skriptzuordnung stehen im
[Konfigurationsvertrag](CONFIGURATION.md).

## 6. Statische Vorprüfung

Vor jedem späteren Deployment prüft der Betreiber ohne Containerstart:

1. Alle als Pflicht markierten Variablen sind gesetzt.
2. `CODESERVER_IMAGE_TAG` ist ein explizites freigegebenes Versionstag und
   weder `CHANGE_ME` noch `latest`.
3. Config-, Secret-, Backup- und Restorepfade sind absolut und voneinander
   getrennt.
4. Die Secret-Datei ist eine vorhandene reguläre, nicht leere Datei.
5. Die Secret-Datei hat Modus `0600`; Metadaten passen zum lokalen
   Administrationsmodell.
6. `CODESERVER_BIND_ADDRESS` ist exakt `127.0.0.1`.
7. Eine produktive `.env` ist nicht vorhanden und nicht erforderlich.
8. `scripts/verify-installation.sh --static` und die dokumentierte statische
   Compose-Validierung sind erfolgreich.

Zukünftige lokale Metadatenprüfungen mit Platzhaltern:

```bash
test -d "<CODESERVER_CONFIG_PATH>"
test -s "<CODESERVER_SECRET_FILE>"
test "$(stat -c '%a' "<CODESERVER_SECRET_FILE>")" = "600"
```

Der Secret-Inhalt wird dabei nicht gelesen oder ausgegeben.

## 7. Deployment

`EXTERNAL OPERATOR ACTION` — in MIG-004 nicht ausführen:

1. In Portainer **Stacks** öffnen und einen neuen Git-Repository-Stack wählen.
2. Repository URL, Reference und Compose path exakt wie oben eintragen.
3. Automatische GitOps-Updates deaktiviert lassen.
4. Alle lokalen Variablen erfassen und vor dem Speichern erneut vergleichen.
5. Den gerenderten Stack auf Image, Loopback-Port, genau zwei Mounts und
   fehlende Klartextpasswortvariablen prüfen.
6. Deployment manuell auslösen.
7. Erst nach erfolgreicher Verifikation den Stack als abgenommen markieren.

Bis MIG-010 existiert kein freigegebenes Image; vorher muss der Vorgang sicher
abgebrochen werden.

## 8. GitHub CLI einmalig anmelden

Die GitHub CLI ist im Image enthalten; die Authentifizierung ist ausschließlich
eine interaktive Betreiberaktion im Terminal des bereits deployten
code-server. Die geprüfte LinuxServer-Basis setzt `HOME=/config`, und die
offizielle GitHub CLI verwendet ohne abweichende XDG- oder
`GH_CONFIG_DIR`-Vorgabe `$HOME/.config/gh`. Der erwartete persistente
Konfigurationspfad ist deshalb `/config/.config/gh`.

Vor der Anmeldung führt der Betreiber im laufenden Container aus:

```bash
command -v gh
gh --version
node --version
pnpm --version
pwsh --version
codex --version
printf 'HOME=%s\n' "$HOME"
printf 'XDG_CONFIG_HOME=%s\n' "${XDG_CONFIG_HOME:-}"
printf 'GH_CONFIG_DIR=%s\n' "${GH_CONFIG_DIR:-}"
printf 'GH_TELEMETRY=%s\n' "${GH_TELEMETRY:-}"
gh config get --host github.com git_protocol
```

Alle Befehle müssen erfolgreich sein, `HOME` muss `/config` und
`GH_TELEMETRY` muss `false` ausgeben. Falls der reale Container davon abweicht
oder eine lokal gesetzte XDG-/`GH_CONFIG_DIR`-Variable den Pfad verändert,
wird die Anmeldung abgebrochen und der Persistenzvertrag separat reviewt. Es
wird kein Pfad geraten. Beim dokumentierten Standard ist kein zusätzliches
`GH_CONFIG_DIR` erforderlich.

Die Repositoryskripte `scripts/verify-developer-tools.sh` und
`scripts/verify-toolchain.sh` werden aus dem ausgecheckten Repository
ausgeführt. Sie sind keine Containerdateien, weil das Dockerfile keine
Repositorydateien per `COPY` oder `ADD` in das Image übernimmt.

`GH_TELEMETRY=false` deaktiviert die pseudonyme GitHub-CLI-Telemetrie im Image
standardmäßig und ist kein Secret. Eine lokale Abweichung benötigt eine
ausdrückliche Betreiberentscheidung. GitHub-CLI-Erweiterungen können eigene
Telemetrie besitzen und müssen separat bewertet werden.

Danach startet der Betreiber genau einmal den Web-Login und folgt dem
interaktiven Browserablauf:

```bash
gh auth login --hostname github.com --git-protocol https --web
gh auth status
```

Nach der Anmeldung wird ausschließlich die Existenz der erwarteten
Authentifizierungsdatei geprüft, niemals ihr Inhalt. Anschließend wird der
Testcontainer mit demselben `/config`-Mount neu gestartet und `gh auth status`
erneut ausgeführt. Nur wenn die Anmeldung danach weiter besteht, ist die
Authentifizierungspersistenz nachgewiesen.

Die Anmeldung darf weder im Image-Build noch in CI, Compose oder einem
Repositoryskript automatisiert werden. GitHub-Token, Ausgaben mit Credentials
und Dateien wie `/config/.config/gh/hosts.yml` werden nicht in das Image
eingebaut, nicht in Git eingecheckt, nicht als öffentliche Compose-Werte
gepflegt und nicht in README, Issues, Pull Requests oder Logs kopiert. Der
gesamte GitHub-CLI-Konfigurationsbereich bleibt lokaler, sensibler
Betreiberzustand im persistenten `/config`-Mount.

## 9. SoSeBaMa-CLI und Sicherheitsgrenze

MIG-017 stellt im Image für `amd64` und `arm64` ausschließlich systemweite
CLIs bereit: pnpm `11.19.0`, PostgreSQL-Client `18.4-1.pgdg24.04+1`, Docker
CLI `5:29.7.0-1~ubuntu.24.04~noble`, Compose V2
`5.3.1-1~ubuntu.24.04~noble`, Buildx `0.36.0-1~ubuntu.24.04~noble` und Trivy
`0.72.0`. Die Quellen, Keyring-Fingerprints und Prüfsummen stehen im
Dockerfile und in `README.md`.

Der Container enthält keinen `docker-ce`-/`docker.io`-Daemon, kein `dockerd`,
kein `containerd`, keine Docker-Gruppe, keine zusätzlichen Capabilities und
keinen `/var/run/docker.sock`. Die folgenden Befehle sind im laufenden
Der LinuxServer-s6-Initprozess startet gemäß Basisimagevertrag und wendet `PUID`/`PGID` an. Der code-server-Dienst läuft danach mit der festgelegten Nicht-Root-UID; Root-Initprozess und Dienst erhalten keinen Docker-Socket, keine zusätzlichen Capabilities und keinen privilegierten Modus. Der Zugriff bleibt auf explizite Mounts und Containergrenzen beschränkt.

Container daemonlos möglich und dürfen keinen Socket-Mount voraussetzen:

```bash
node --version
pnpm --version
psql --version
pg_isready --version
pg_dump --version
pg_restore --version
docker --version
docker compose version
docker buildx version
trivy --version
test ! -S /var/run/docker.sock
! command -v dockerd
! command -v containerd
```

Der Trivy-Cache liegt unter `/config/.cache/trivy`; produktive Scanberichte
oder Secrets gehören nicht in diesen Cache. Der echte Multiarch-Build, der
isolierte `amd64`-Runtime-Smoke-Test und die Trivy-Dateisystem-,
Konfigurations- und Image-Scans laufen ausschließlich auf GitHub-hosted
Runnern. Jeder ungeklärte `HIGH`- oder `CRITICAL`-Befund blockiert den PR;
`MEDIUM` und niedrigere Befunde werden nur zusammengefasst.

React, Vite, NestJS, TypeScript, Prisma, Vitest, Playwright, Testcontainers,
Zod, Dexie, PDF.js, `react-konva`, `pg-boss` und qpdf werden nicht global in
dieses Basisimage installiert. Diese Abhängigkeiten werden im SoSeBaMa-
Repository oder in dedizierten Anwendungs-/Prüfimages fixiert.

## 10. Reverse Proxy

Der öffentliche Vertrag lautet ausschließlich:

```text
HTTPS Reverse Proxy
→ 127.0.0.1:<CODESERVER_HOST_PORT>
```

DSM hält Domain, Zertifikat, WebSocket- und Firewallkonfiguration lokal.
Direkter externer Zugriff auf den veröffentlichten Containerport ist nicht Teil
des Vertrags.

## 11. Verifikation

Nach einem späteren Deployment werden als `EXTERNAL OPERATOR ACTION` geprüft:

- Containerstatus ist `running`;
- Healthstatus ist `healthy`;
- Port `8443/tcp` ist ausschließlich an Loopback veröffentlicht;
- Login über den HTTPS-Reverse-Proxy;
- persistenter Workspace nach einer kontrollierten Neuerstellung;
- Terminal und tatsächlich installierte Imagewerkzeuge mit den in Abschnitt 8
  genannten Versionsbefehlen;
- GitHub-CLI-Konfigurationspfad sowie Anmeldung über einen Containerneustart,
  jeweils ohne Credential-Ausgabe;
- `/config`-Mount und read-only Secret-Mount;
- Logs auf Fehler, jedoch ohne Secret-Inhalte oder Environment-Werte
  auszugeben.

Die Repositoryprüfung `scripts/verify-installation.sh --runtime` wird nur aus
einem ausgecheckten Repository und mit ausdrücklich freigegebenem Dockerzugriff
gestartet; sie wird nicht innerhalb des Images ausgeführt.

## 12. Rollback

Bei einem fehlgeschlagenen späteren Cutover:

1. Das vorherige bekannte gute Imageversionstag in Portainer eintragen.
2. Den Stack manuell neu deployen.
3. Persistente Verzeichnisse nicht löschen oder überschreiben.
4. Die Secret-Datei nicht löschen oder ersetzen.
5. Health und Funktion erneut prüfen.
6. Das alte Image bis zur vollständig abgeschlossenen Migration behalten.

Das ausführliche Verfahren steht unter
[Updates und Rollbacks](UPDATE-ROLLBACK.md).
