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

Die zukünftige CI validiert Repository und Compose-Vertrag und baut
`linux/amd64` ohne Push. Der Publish-Workflow akzeptiert ausschließlich
strikte Release-Tags `vMAJOR.MINOR.PATCH` und veröffentlicht ausschließlich
`MAJOR.MINOR.PATCH` sowie `sha-<full-commit>`. `MAJOR.MINOR`, `MAJOR`,
`latest` und Imagetags mit führendem `v` sind ausgeschlossen. Portainer
verwendet den vollständigen Patch-Tag oder den geprüften Digest. Digest, SBOM
und Provenienz-Attestation bilden den späteren Freigabenachweis. Details stehen
unter [CI und Container-Publishing](docs/CI-CD.md) und
[Releases](docs/RELEASES.md).

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
