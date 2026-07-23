# Konfigurationsvertrag

Dieses Repository enthält ausschließlich den öffentlichen Vertrag. Die Datei
[`.env.example`](../.env.example) ist eine kommentierte Referenz und keine
produktive Konfigurationsquelle. Produktive Stackvariablen werden lokal in
Portainer gepflegt; eine produktive `.env` ist weder erforderlich noch
vorgesehen.

## Klassifikation

- `PUBLIC_DEFAULT`: öffentlicher, nicht sensitiver Default im Repository.
- `LOCAL_REQUIRED`: lokal zu ermittelnder und verpflichtend zu setzender Wert.
- `LOCAL_OPTIONAL`: lokaler Wert mit sicherem Default oder leerem Zustand.
- `SECRET_PATH`: lokaler Dateipfad; der Pfad ist nicht der Secret-Inhalt.

## Finale Portainer-/Compose-Matrix

| Variable | Klasse | Zweck | Pflicht | Default | Öffentlicher Beispielwert | Sensitivität | Konfigurationsort | Verbraucher | Validierungsregel |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `CODESERVER_IMAGE_REPOSITORY` | `PUBLIC_DEFAULT` | GHCR-Repository des Images | Nein | `ghcr.io/tomas-fuerl/codeserver` | `ghcr.io/tomas-fuerl/codeserver` | Öffentlich | Portainer; Default in Compose | `compose.yaml` | Gültiger Image-Repositoryname ohne Tag |
| `CODESERVER_IMAGE_TAG` | `LOCAL_REQUIRED` | Explizite freigegebene Imageversion | Ja | Keiner | `CHANGE_ME` nur als Warnplatzhalter | Nicht geheim | Portainer | `compose.yaml` | Nicht leer, nicht `CHANGE_ME`, niemals `latest`; freigegebenes unveränderliches Versionstag |
| `CODESERVER_CONTAINER_NAME` | `PUBLIC_DEFAULT` | Stabiler lokaler Containername | Nein | `codeserver` | `codeserver` | Öffentlich | Portainer; Default in Compose | Compose und Betriebsskripte | Nicht leer; zulässiger Containername |
| `CODESERVER_BIND_ADDRESS` | `PUBLIC_DEFAULT` | Hostadresse der Portveröffentlichung | Nein | `127.0.0.1` | `127.0.0.1` | Öffentlich | Portainer; Default in Compose | `compose.yaml` | Für diesen Vertrag exakt `127.0.0.1` |
| `CODESERVER_HOST_PORT` | `PUBLIC_DEFAULT` | Lokaler Reverse-Proxy-Zielport | Nein | `8377` | `8377` | Öffentlich | Portainer; Default in Compose | `compose.yaml` | Dezimaler TCP-Port von 1 bis 65535 |
| `CODESERVER_CONFIG_PATH` | `LOCAL_REQUIRED` | Synology-Bind-Mountquelle für `/config` | Ja | Keiner | `/example/synology/docker/codeserver` | Lokaler Pfad, kein Secret | Portainer | `compose.yaml` | Absoluter, vorhandener Verzeichnispfad; nicht `CHANGE_ME` |
| `CODESERVER_SECRET_FILE` | `SECRET_PATH` | Synology-Pfad der Passwort-Hashdatei | Ja | Keiner | `/example/synology/docker/codeserver-secrets/hashed_password` | Pfad lokal; Inhalt geheim | Portainer | `compose.yaml` | Absoluter Pfad, reguläre nicht leere Datei namens `hashed_password`, Modus `0600` |
| `CODESERVER_BACKUP_PATH` | `LOCAL_REQUIRED` | Lokales Ziel für Backuparchive | Für Backupbetrieb | Keiner | `/example/synology/docker/codeserver-backups` | Lokaler Pfad, kein Secret | Portainer-Betriebsdokumentation | Zuordnung zu `CODESERVER_BACKUP_ROOT` | Absolut; getrennt von Config und Secret; nicht innerhalb des Configpfads |
| `CODESERVER_RESTORE_PATH` | `LOCAL_REQUIRED` | Basis für nicht-destruktive Restore-Tests | Für Restore-Tests | Keiner | `/example/synology/docker/codeserver-restore-tests` | Lokaler Pfad, kein Secret | Portainer-Betriebsdokumentation | Zuordnung zu `CODESERVER_RESTORE_ROOT` | Absolut; getrennt von Config und Secret; Restoreziele liegen strikt darunter |
| `PUID` | `LOCAL_REQUIRED` | UID für Dateien unter `/config` | Ja | Keiner | `1000` | Lokal, kein Secret | Portainer | Container-Environment | Positive dezimale UID, lokal auf der Synology ermittelt |
| `PGID` | `LOCAL_REQUIRED` | GID für Dateien unter `/config` | Ja | Keiner | `1000` | Lokal, kein Secret | Portainer | Container-Environment | Positive dezimale GID, lokal auf der Synology ermittelt |
| `TZ` | `LOCAL_OPTIONAL` | Containerzeitzone | Nein | `Europe/Berlin` | `Europe/Berlin` | Öffentlich | Portainer; Default in Compose | Container-Environment | Gültiger IANA-Zeitzonenname |
| `PROXY_DOMAIN` | `LOCAL_OPTIONAL` | Hostname für proxybezogene Anwendungseinstellungen | Nein | Leer | `codeserver.example.com` | Lokaler Infrastrukturwert | Portainer | Container-Environment | Leer oder DNS-Hostname ohne Schema, Port und Pfad |

Die Werte `1000` für `PUID` und `PGID` sind ausschließlich öffentliche
Beispiele. Sie sind nicht als korrekte Synology-Werte zugesichert.

`CODESERVER_BACKUP_PATH` und `CODESERVER_RESTORE_PATH` dokumentieren lokale
Betriebspfade, werden aber nicht in den Container gemountet. Die korrespondierenden
Skriptvariablen werden bei einem späteren manuellen Skriptaufruf ausdrücklich
gesetzt; die Skripte lesen keine produktive Environment-Datei.

## Interne feste Containerwerte

| Name | Klasse | Wert | Ort | Bedeutung und Validierung |
| --- | --- | --- | --- | --- |
| `FILE__HASHED_PASSWORD` | `PUBLIC_DEFAULT` | `/run/secrets/hashed_password` | Fest in `compose.yaml` | Interner Dateiverweis. Kein Portainer-Eingabewert und kein Passwort-Hash. Muss exakt auf das read-only Mountziel zeigen. |

Der Hash darf insbesondere nicht über `PASSWORD`, `HASHED_PASSWORD`,
`SUDO_PASSWORD` oder `FILE__PASSWORD` als Environment-Variable in den
Container gelangen.

## GitHub-CLI-Authentifizierung und Telemetrie

`gh` ist ein Imagewerkzeug und benötigt keine öffentliche Compose-Variable.
Die Anmeldung ist eine einmalige interaktive Betreiberaktion nach Deployment:

```bash
gh auth login --hostname github.com --git-protocol https --web
gh auth status
```

Die offizielle LinuxServer-Basis setzt `HOME=/config`; die GitHub CLI verwendet
ohne abweichende XDG- oder `GH_CONFIG_DIR`-Vorgabe standardmäßig
`$HOME/.config/gh`, hier also `/config/.config/gh`. Der vorhandene `/config`-
Bind-Mount persistiert diesen lokalen Zustand. Vor der Anmeldung werden HOME
und das tatsächliche `gh`-Verhalten im laufenden Container wie in
[Synology und Portainer](SYNOLOGY-PORTAINER.md) geprüft. GitHub-Token,
`hosts.yml` und andere Authentifizierungsdaten sind keine Portainer-Variable,
kein öffentlicher Compose-Wert und niemals Repository- oder Imageinhalt.

Das Image setzt reproduzierbar `GH_TELEMETRY=false`; die pseudonyme
GitHub-CLI-Telemetrie ist damit standardmäßig deaktiviert. Der Wert ist eine
öffentliche Verhaltenssteuerung und kein Secret. Er wird nicht als zusätzliche
Compose-Variable benötigt. Eine lokale Abweichung darf nur durch eine
ausdrückliche Betreiberentscheidung erfolgen. GitHub-CLI-Erweiterungen können
eigene Telemetrie implementieren und müssen unabhängig vom `gh`-Default vor
Installation oder Aktivierung separat bewertet werden.

## Vertrag zwischen Compose- und Skriptvariablen

| Portainer-/Compose-Wert | Explizite Skriptvariable | Klasse | Regel |
| --- | --- | --- | --- |
| `CODESERVER_CONFIG_PATH` | `CODESERVER_CONFIG_ROOT` | `LOCAL_REQUIRED` | Derselbe absolute Konfigurationspfad |
| Elternverzeichnis von `CODESERVER_SECRET_FILE` | `CODESERVER_SECRET_ROOT` | `SECRET_PATH` | Enthält genau die erwartete Datei `hashed_password` |
| `CODESERVER_BACKUP_PATH` | `CODESERVER_BACKUP_ROOT` | `LOCAL_REQUIRED` | Dasselbe absolute Backupverzeichnis |
| `CODESERVER_RESTORE_PATH` | `CODESERVER_RESTORE_ROOT` | `LOCAL_REQUIRED` | Dieselbe absolute Basis für Restore-Testziele |
| `CODESERVER_CONTAINER_NAME` | `CODESERVER_CONTAINER_NAME` | `LOCAL_REQUIRED` | Derselbe Containername; bei Skriptaufrufen explizit setzen |

Die Betriebsskripte besitzen keine produktiven Pfaddefaults. Fehlende Werte,
leere Werte oder `CHANGE_ME` führen vor Datei- oder Dockeroperationen zum
Abbruch. Pfade müssen absolut und anhand der dokumentierten Trennungsregeln
sicher sein.

## Quelle der Werte

Für einen produktiven Portainer-Git-Stack werden alle Stackvariablen in
Portainer erfasst. `.env.example` dient nur zum Abgleich der Namen und
öffentlichen Beispiele. Weder ein Secret-Wert noch eine produktive lokale
Konfigurationsdatei wird in dieses Repository kopiert. Die vollständige
Installationsanleitung steht in
[Synology und Portainer](SYNOLOGY-PORTAINER.md).
