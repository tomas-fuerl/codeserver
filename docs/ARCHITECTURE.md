# Architektur

## Lieferkette

Die Zielarchitektur trennt Quelle, Image, Deployment und lokalen Zustand:

GitHub-Repository → GitHub Actions → GHCR → Portainer-Git-Stack →
code-server-Container → lokale Synology-Bind-Mounts.

Das Repository stellt `Dockerfile`, `compose.yaml` und den öffentlichen
Konfigurationsvertrag bereit. GitHub Actions und GHCR werden erst in späteren
Migrationstasks aktiviert. Dieses Dokument behauptet weder ein bereits
veröffentlichtes Image noch einen produktiven Deploymentstand.

## Öffentlicher Repositoryzustand

Das Repository enthält:

- die reproduzierbare Imagequelle;
- genau eine Compose-Datei mit dem Dienst `code-server`;
- öffentliche Variablennamen und Beispielwerte;
- Betreiber-, Architektur-, Backup-, Restore-, Update- und
  Rollbackdokumentation;
- statische und ausdrücklich getrennte Runtimeprüfungen.

Es enthält keine produktive Environment-Datei, Secrets, lokale
Infrastrukturwerte oder Betriebsdaten. Der vollständige Variablenvertrag steht
in [CONFIGURATION.md](CONFIGURATION.md).

## Imagezustand

Das Dockerfile basiert auf `lscr.io/linuxserver/code-server:4.131.0-ls354`
mit vollständig gepinntem SHA-256-Manifest-Digest. GitHub CLI, Node und
PowerShell werden aus exakt gepinnten offiziellen Releases installiert und
gegen offizielle SHA-256-Werte geprüft; pnpm und Codex sind exakt gepinnte
öffentliche npm-Pakete. `GH_TELEMETRY=false` deaktiviert die pseudonyme
GitHub-CLI-Telemetrie als reproduzierbaren Image-Default. Das OCI-Source-Label
verweist auf dieses Repository.

MIG-017 erweitert den systemweiten Entwicklungsumfang reproduzierbar:
`pnpm 11.19.0` wird als npm-Paket mit Registry-Integrity installiert;
`postgresql-client-18 18.4-1.pgdg24.04+1` kommt aus dem signierten offiziellen
PGDG-Repository; Docker CLI `5:29.7.0-1~ubuntu.24.04~noble`, Compose V2
`5.3.1-1~ubuntu.24.04~noble` und Buildx `0.36.0-1~ubuntu.24.04~noble` kommen
aus dem signierten offiziellen Docker-Repository; Trivy `0.72.0` kommt aus
dem offiziellen Aqua-Security-Archiv mit geprüfter Release-Checksummenliste.
Alle Pins gelten für Ubuntu Noble auf `amd64` und `arm64`; der Basisdigest
wurde auf den aktuell veröffentlichten `4.131.0-ls354`-Manifeststand aktualisiert,
um die erste CI-Befundlage gezielt zu remediieren.

Der LinuxServer-s6-Initprozess wird gemäß dem Basisimagevertrag gestartet und wendet `PUID` und `PGID` während der Initialisierung an. Erst danach läuft der code-server-Anwendungsdienst mit der erwarteten Nicht-Root-UID. Der Initprozess erhält keinen Docker-Socket, keine zusätzlichen Capabilities und keinen privilegierten Modus; der Dienstzugriff bleibt auf die expliziten Mounts und Containergrenzen beschränkt.

Die Werkzeuge sind CLIs. Der Build installiert weder `docker-ce` noch
`docker.io`, `dockerd`, `containerd` oder `containerd.io`, richtet keine
Docker-Gruppe ein und startet keinen Dienst. Der Container erhält keinen
Docker-Socket, keine zusätzlichen Capabilities und keinen privilegierten Modus.
`docker compose version`, `docker buildx version`, PostgreSQL-Clientbefehle und
`trivy --version` funktionieren daemonlos. Trivy legt seinen Cache unter
`/config/.cache/trivy` ab. GitHub-hosted CI führt zusätzlich den echten
Multiarch-Build, den isolierten `amd64`-Runtime-Smoke-Test und die Trivy-
Dateisystem-, Konfigurations- und Image-Scans aus; ungeklärte `HIGH`- oder
`CRITICAL`-Befunde blockieren vor dem Merge.

Das produktive Imageformat ist
`ghcr.io/tomas-fuerl/codeserver:<VERSION>`. `<VERSION>` bezeichnet später ein
explizites, freigegebenes und unveränderliches Versionstag. `latest`, lokale
Produktivbuilds auf der Synology und ein impliziter Image-Tag sind nicht Teil
des Vertrags.

MIG-005 definiert erst den Workflow. Das erste veröffentlichte Image folgt
frühestens in MIG-010.

## Portainerzustand

Portainer lädt später:

- Repository: `https://github.com/tomas-fuerl/codeserver.git`;
- Reference: `main`;
- Compose-Pfad: `compose.yaml`.

Portainer hält die realen Stackvariablen, einschließlich Imageversion,
Containername, Loopback-Port, UID/GID, Zeitzone, Domain und lokaler
Mountquellen. Automatische GitOps-Aktualisierungen bleiben beim ersten
Cutover deaktiviert. Einzelheiten stehen in
[SYNOLOGY-PORTAINER.md](SYNOLOGY-PORTAINER.md).

## Synology-Persistenzzustand

Der Synology-Host hält außerhalb von Git und Image:

- den persistenten `/config`-Quellpfad einschließlich Workspace;
- die lokal vom Betreiber erzeugte GitHub-CLI-Authentifizierung unter
  `/config/.config/gh`;
- die einzelne lokale Datei `hashed_password`;
- Backupverzeichnis und Restore-Testbasis;
- Dateieigentümer und Rechte;
- DSM-Aufgabenplanung;
- Reverse Proxy, Zertifikate und Firewall.

Ein Containerwechsel darf Persistenz, Secret, Backups oder Restore-Testdaten
nicht löschen. Backup- und Restorepfade werden nicht in den Container
gemountet.

Die GitHub CLI gehört zum reproduzierbaren Image. Ihre interaktive Anmeldung
und die dabei entstehenden Credentials gehören dagegen zum lokalen
persistenten `/config`-Zustand. Token und `hosts.yml` sind weder Image- noch
Repository- oder öffentlicher Compose-Zustand. Die LinuxServer-Basis setzt
`HOME=/config`; ein zusätzliches `GH_CONFIG_DIR` ist deshalb im aktuellen
Vertrag nicht erforderlich. `GH_TELEMETRY=false` ist kein Secret; eine lokale
Abweichung benötigt eine ausdrückliche Betreiberentscheidung. Erweiterungen
der GitHub CLI können eigene Telemetrie besitzen und werden separat bewertet.

## Netzwerk- und Secretgrenze

Compose veröffentlicht ausschließlich Containerport `8443` mit dem sicheren
Default `127.0.0.1:8377`. Ein optionaler HTTPS-Reverse-Proxy leitet lokal auf
`127.0.0.1:<CODESERVER_HOST_PORT>` weiter.

Die Secret-Datei wird read-only nach `/run/secrets/hashed_password` gemountet.
`FILE__HASHED_PASSWORD` verweist fest auf diesen Containerpfad. Der Hashwert
ist weder Portainer-Variable noch Container-Environment-Wert.

## Verantwortungsfluss

| Bereich | Verantwortlich |
| --- | --- |
| Quellcode, Vertrag und Reviews | Öffentliches GitHub-Repository nach MIG-009 |
| Build und Provenienz | GitHub Actions ab MIG-005 |
| Versionierte Images | GHCR ab MIG-010 |
| Stackquelle und produktive Variablen | Portainer |
| Persistenz, Secret und Backups | Synology-Dateisystem |
| HTTPS, Zertifikate und Netzwerkzugriff | DSM und lokale Netzwerkinfrastruktur |

Alle Portainer-, Synology- und DSM-Änderungen sind spätere externe
Betreiberaktionen.
