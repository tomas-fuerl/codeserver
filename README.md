# codeserver

Dieses Repository definiert ein reproduzierbares code-server-Image und dessen
kontrollierten Betrieb auf einer Synology mit Portainer.

## Lieferweg

Der vorgesehene Lieferweg ist:

GitHub-Repository → GitHub Actions → GHCR → Portainer → code-server.

Portainer lädt später den Git-Stack aus
`https://github.com/tomas-fuerl/codeserver.git`, Reference `main`,
Compose-Pfad `compose.yaml`, und verwendet ein explizites Image
`ghcr.io/tomas-fuerl/codeserver:<VERSION>`.

Die CI- und GHCR-Publish-Workflows sind lokal definiert und statisch geprüft.
Sie wurden in diesem history-freien Arbeitsbaum nicht online ausgeführt.
Repository und Workflows werden erst in MIG-009 veröffentlicht; das erste
Image entsteht frühestens in MIG-010. Dieser Stand behauptet deshalb weder ein
verfügbares Releaseimage noch eine produktiv erfolgreiche Installation.

## Qualität und Releases

Das lokale, daemonfreie Repository-Gate ist:

```bash
./scripts/ci/validate-repository.sh
```

Die PR-CI validiert Repository und Compose-Vertrag und baut
`linux/amd64` sowie `linux/arm64` ohne Push; der Publish-Workflow bleibt
separat. Er akzeptiert ausschließlich
strikte Release-Tags `vMAJOR.MINOR.PATCH` und veröffentlicht ausschließlich
`MAJOR.MINOR.PATCH` sowie `sha-<full-commit>`. `MAJOR.MINOR`, `MAJOR`,
`latest` und Imagetags mit führendem `v` sind ausgeschlossen. Portainer
verwendet den vollständigen Patch-Tag oder den geprüften Digest. Digest, SBOM
und Provenienz-Attestation bilden den späteren Freigabenachweis. Details stehen
unter [CI und Container-Publishing](docs/CI-CD.md) und
[Releases](docs/RELEASES.md).

## SoSeBaMa-Toolchain (MIG-017)

Das Entwicklungsimage enthält systemweite CLI-Werkzeuge, aber keinen Docker-
Daemon und keinen Docker-Socket. Die Basis bleibt der aktuelle, vollständig
digestfixierte LinuxServer-Stand `4.131.0-ls354` (`sha256:621d…bad7`) für
`linux/amd64` und `linux/arm64`; ein allgemeines `dist-upgrade` ist nicht Teil
des Builds.

| Werkzeug | Exakte Version | Offizielle Quelle und Integritätsnachweis |
| --- | --- | --- |
| Node.js | `24.18.1` (unverändert) | nodejs.org-Archiv und `SHASUMS256.txt` |
| GitHub CLI | `2.97.0` | offizielles GitHub-Releasearchiv, Checksummenlisten-Asset SHA-256 `61905c69ec8660f310814ec98395cdd0c2d07aabf024c597ec45813984a02334` |
| PowerShell | `7.6.4` | offizielles PowerShell-Releasearchiv, architekturspezifische SHA-256-Prüfsummen |
| Codex CLI | `0.144.5` | offizielles npm-Paket `@openai/codex@0.144.5` |
| pnpm | `11.19.0` | npm-Paket `pnpm@11.19.0`, Registry-Integrity `sha512-eIHz7VkNRyxKlV4riLISF5ERYGbcyIy8o4SeybYPG7qm0syyIfqR2k4cZb7yvL43k2Wup6xTnHv4be3DobItzg==` |
| PostgreSQL-Client | `18.4-1.pgdg24.04+1` | offizielles PGDG-Repository, Fingerprint `B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8`, `signed-by`-Keyring |
| Docker CLI | `5:29.7.0-1~ubuntu.24.04~noble` | offizielles Docker-Repository, Fingerprint `9DC858229FC7DD38854AE2D88D81803C0EBFCD88`, `signed-by`-Keyring |
| Compose V2 | `5.3.1-1~ubuntu.24.04~noble` | dasselbe Docker-Repository und derselbe signierte Paketindex |
| Buildx | `0.36.0-1~ubuntu.24.04~noble` | dasselbe Docker-Repository und derselbe signierte Paketindex |
| Trivy | `0.72.0` | offizielles Aqua-Security-Archiv, geprüfte Checksummenliste und architekturspezifische SHA-256-Prüfsumme |

Der normale LinuxServer-Startvertrag bleibt erhalten: LinuxServer startet den s6-Initprozess entsprechend dem Basisimagevertrag und wendet dabei `PUID`/`PGID` an. Der code-server-Dienst läuft nach dieser Initialisierung mit der festgelegten Nicht-Root-UID. Der Root-Initprozess erhält keinen Docker-Socket, keine zusätzlichen Capabilities und keinen privilegierten Modus; der Dienstzugriff bleibt auf explizite Mounts und Containergrenzen beschränkt.

PGDG- und Docker-Pakete sind für Ubuntu Noble auf `amd64` und `arm64`
verfügbar. Trivy verwendet `/config/.cache/trivy`; dort liegen keine
produktiven Scanberichte oder Secrets. Im normalen Container werden weder
`docker-ce`, `docker.io`, `dockerd`, `containerd` noch `containerd.io`
installiert; Compose und Buildx sind ausschließlich CLI-Plugins. Ein fehlender
`/var/run/docker.sock` ist deshalb ein beabsichtigtes Sicherheitsmerkmal.

Lokal ohne Daemon sind Versions- und Vertragstests möglich:

```bash
./scripts/verify-developer-tools.sh
./scripts/verify-toolchain.sh
./scripts/verify-installation.sh --static
./scripts/ci/run-trivy-scan.sh --help
```

Der echte Multiarch-Build, Runtime-Smoke-Test und Image-Scan laufen nur auf
GitHub-hosted Runnern. CI baut `linux/amd64` und `linux/arm64`, startet nur für
`amd64` einen isolierten Container ohne Mounts, Secrets oder Socket und lässt
Trivy bei jedem ungeklärten `HIGH`- oder `CRITICAL`-Befund fehlschlagen.
`MEDIUM` und niedrigere Befunde werden im Laufprotokoll zusammengefasst.

React, Vite, NestJS, TypeScript, Prisma, Vitest, Playwright, Testcontainers,
Zod, Dexie, PDF.js, `react-konva`, `pg-boss` und qpdf gehören nicht global in
dieses Image. Diese Abhängigkeiten werden später im SoSeBaMa-Repository oder
in dedizierten Anwendungs- und Prüfimages fixiert.

Werkzeugupdates erfolgen durch Änderung der benannten `ARG`-Pins, erneute
Quellen-/Checksumprüfung und grüne PR-CI. Bei einem fehlenden Patch oder einem
ungeklärten `HIGH`/`CRITICAL`-Befund bleibt MIG-017 blockiert. Rollbacks setzen
den vorherigen freigegebenen Image-Digest in Portainer; persistente Daten,
Secrets und der Docker-Daemon bleiben unangetastet.

## Öffentlicher Vertrag und lokaler Zustand

Versioniert werden Dockerfile, `compose.yaml`, öffentliche Beispielwerte,
Dokumentation, Extension-Manifeste und Betriebsskripte. Das Repository enthält
keine lokale produktive Konfiguration. Die restriktive `.dockerignore`
begrenzt den Docker-Buildkontext auf nachgewiesene Dockerfile-Eingaben;
aktuell sind dies keine lokalen `COPY`-/`ADD`-Quellen. `.gitignore` steuert
dagegen ausschließlich die Git-Versionierung und ersetzt diese Allowlist
nicht.

Portainer hält die produktiven Stackvariablen. Das Synology-Dateisystem hält
persistente Konfiguration, Workspace, Secret-Datei, Backups und
Restore-Testbereiche. Reale UID/GID, Domain, Reverse Proxy, Firewall und
DSM-Aufgabenplanung bleiben ebenfalls lokal.

Die Passwort-Authentifizierung wird ausschließlich über eine lokale,
read-only eingebundene Datei bereitgestellt. Ein Passwort-Hash wird nie als
Environment-Variable oder Repositoryinhalt gepflegt.

## GitHub CLI und Betreiberanmeldung

Das Image enthält die im `Dockerfile` exakt gepinnte GitHub CLI `gh`. Die
GitHub-Anmeldung gehört nicht zum Image-Build: Sie wird nach Deployment einmal
interaktiv vom Betreiber im Terminal des laufenden code-server ausgeführt.

Der reproduzierbare Imagevertrag setzt `GH_TELEMETRY=false` und deaktiviert
damit die pseudonyme GitHub-CLI-Telemetrie standardmäßig. Dieser öffentliche
Steuerwert ist kein Secret. Eine lokale Abweichung erfordert eine ausdrückliche
Betreiberentscheidung. GitHub-CLI-Erweiterungen können unabhängig davon eigene
Telemetrie besitzen und müssen vor ihrer Nutzung separat bewertet werden.

Die geprüfte LinuxServer-Basis setzt `HOME=/config`. Ohne abweichendes
`XDG_CONFIG_HOME` oder `GH_CONFIG_DIR` verwendet `gh` daher den persistenten
Pfad `/config/.config/gh`. Vor der Anmeldung prüft der Betreiber den realen
Containerwert und das Git-Protokoll wie in der
[Synology- und Portainer-Anleitung](docs/SYNOLOGY-PORTAINER.md) beschrieben.
Ein zusätzliches `GH_CONFIG_DIR` ist für diesen Imagevertrag nicht vorgesehen.

```bash
gh auth login --hostname github.com --git-protocol https --web
gh auth status
```

GitHub-Token, `gh`-Authentifizierungsdateien wie `hosts.yml` und sonstige
Credentials sind ausschließlich lokaler, persistenter Betreiberzustand. Sie
werden nie in das Image eingebaut, in Git eingecheckt, als öffentliche
Compose-Werte gepflegt oder in README, Issues, Pull Requests und Logs
ausgegeben.

## Schnellstart für Betreiber

1. [Konfigurationsvertrag](docs/CONFIGURATION.md) lesen und lokale Werte
   ermitteln.
2. [Synology- und Portainer-Anleitung](docs/SYNOLOGY-PORTAINER.md) abarbeiten,
   sobald Repository und Releaseimage verfügbar sind.
3. Vor einem Deployment `scripts/verify-installation.sh --static` und eine
   statische Compose-Validierung ausführen.
4. Update und Rollback ausschließlich über explizite Imageversionen oder einen
   geprüften Digest in Portainer durchführen.

Produktive Aktionen sind manuelle Betreiberaktionen und kein Teil der
Repositoryprüfung.

## Dokumentation

- [Konfigurationsvertrag](docs/CONFIGURATION.md)
- [Synology und Portainer](docs/SYNOLOGY-PORTAINER.md)
- [Architektur](docs/ARCHITECTURE.md)
- [Repository-Layout](docs/REPOSITORY-LAYOUT.md)
- [CI und Container-Publishing](docs/CI-CD.md)
- [Backup und Restore](docs/BACKUP-RESTORE.md)
- [Updates und Rollbacks](docs/UPDATE-ROLLBACK.md)
- [Releasegrundsätze](docs/RELEASES.md)
- [Security Policy](SECURITY.md)
- [Support](SUPPORT.md)
- [Beiträge](CONTRIBUTING.md)
- [Migrationsplan](docs/migration/MIGRATION-PLAN.md)

## Entwicklung und Migration

Änderungen erfolgen taskbezogen auf einem Feature-Branch und werden lokal
statisch geprüft. Die verbindlichen Regeln stehen in [AGENTS.md](AGENTS.md)
und [CONTRIBUTING.md](CONTRIBUTING.md). Der aktuelle Migrationsstatus steht im
[Migrationsplan](docs/migration/MIGRATION-PLAN.md).
