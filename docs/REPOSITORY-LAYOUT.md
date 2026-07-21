# Repository-Layout

## Rootdateien

- `.dockerignore`: restriktive Buildkontext-Allowlist; nach globalem Ausschluss
  sind nur `Dockerfile`, `.dockerignore` und nachgewiesene lokale
  Dockerfile-Eingaben zulässig.
- `.env.example`: kommentierte öffentliche Referenz; keine produktive
  Konfigurationsquelle und kein Ort für Secrets.
- `.gitignore`: Ausschluss lokaler Environment-, Secret-, Backup- und
  Arbeitsartefakte aus der Git-Versionierung; diese Datei begrenzt nicht den
  Docker-Buildkontext.
- `AGENTS.md`: verbindliche Regeln für Repository-Agenten.
- `CONTRIBUTING.md`: öffentlicher Beitrags- und Reviewablauf.
- `Dockerfile`: reproduzierbare Imagequelle.
- `LICENSE`: Lizenz des Repositorys.
- `README.md`: öffentliche Einstiegseite und Dokumentationsindex.
- `SECURITY.md`: Meldeweg und Supply-Chain-Sicherheitsvertrag.
- `SUPPORT.md`: unterstützter Scope und redigierte Diagnoseanforderungen.
- `compose.yaml`: finaler öffentlicher Portainer-Stackvertrag mit genau einem
  Dienst und ohne lokale Produktivwerte.
- `extensions.txt`: gewünschte Extension-IDs ohne Version; `extensions.lock.txt`:
  exakt gepinnte `publisher.extension`-Einträge ohne Metadatenzeilen.

## GitHub-Konfiguration

- `.github/workflows/ci.yml` definiert das read-only Qualitätsgate und einen
  nicht veröffentlichenden `linux/amd64`-Build.
- `.github/workflows/publish-image.yml` veröffentlicht ausschließlich nach
  einem strikten SemVer-Tag, erzeugt nur vollständigen Patch- und Full-SHA-Tag
  sowie Digest, SBOM und Attestation. `MAJOR.MINOR`, `MAJOR` und `latest`
  werden nicht erzeugt.
- `.github/dependabot.yml` schlägt monatlich reviewpflichtige Actions- und
  Docker-Updates vor.
- `.github/pull_request_template.md` hält Scope-, Security-, Prüf- und
  Rollbacknachweise fest.

Diese Dateien sind bis zum Push in MIG-009 nur lokal definiert; MIG-005 führt
keinen Workflow aus.

## Dokumentation

- `docs/ARCHITECTURE.md` trennt Repository-, Image-, Portainer-, Persistenz-,
  Secret- und DSM-Zustand.
- `docs/CONFIGURATION.md` enthält die finale Variablenmatrix und die Zuordnung
  der Betriebsskriptvariablen.
- `docs/CI-CD.md` dokumentiert CI-, Publish-, Berechtigungs-, Tag- und
  Attestationsvertrag.
- `docs/SYNOLOGY-PORTAINER.md` beschreibt die spätere manuelle Installation,
  Vorprüfung, Verifikation und den Rollback.
- `docs/BACKUP-RESTORE.md` beschreibt Backupformat, Verifikation und
  nicht-destruktive Restore-Tests.
- `docs/RELEASES.md` definiert Versionierungs- und Releasegrundsätze.
- `docs/UPDATE-ROLLBACK.md` beschreibt kontrollierte Portainer-Updates und
  Rollbacks.
- `docs/migration/` enthält Plan, Entscheidungen, External-Action-Steuerung,
  Herkunftsnachweis und Taskprotokolle. Historische Herkunftsreferenzen sind
  nur dort zulässig.

## Skripte

- `scripts/backup-config.sh` erstellt und verifiziert später ein Backup mit
  ausschließlich expliziten lokalen Pfadvariablen.
- `scripts/restore-config.sh` extrahiert ausschließlich unter eine explizite
  Restore-Testbasis.
- `scripts/sync-extensions.sh` installiert ausschließlich die gepinnten Einträge der
  Rootdatei `extensions.lock.txt`; ein optionaler Override muss absolut sein.
- `scripts/verify-backup.sh` prüft Archiv, Prüfsumme und Pflichtinhalte.
- `scripts/verify-developer-tools.sh` prüft Entwicklungswerkzeuge.
- `scripts/verify-installation.sh` verwendet standardmäßig den daemonfreien
  Modus `--static`; `--runtime` ist nur eine ausdrückliche Betreiberprüfung.
- `scripts/verify-toolchain.sh` prüft die Image-Toolchain.
- `scripts/ci/validate-repository.sh` bündelt die lokalen statischen Gates.
- `scripts/ci/validate-actions.sh` prüft Trigger, Pins, Berechtigungen und
  Publish-Vertrag ohne YAML-Ausführung.
- `scripts/ci/check-markdown-links.py` validiert relative Dokumentationslinks
  ausschließlich lokal.
- `scripts/security/publication-audit.sh` prüft den Arbeitsbaum vor einer
  öffentlichen Veröffentlichung und darf nicht gelockert werden.

## Nicht versionierter lokaler Zustand

Produktive Environment-Dateien, Secret-Dateien, persistente Konfiguration,
Workspaces, Anwendungsdaten, Backups, Restore-Testdaten, Logs sowie Portainer-,
DSM-, Reverse-Proxy- und Firewallkonfiguration liegen ausdrücklich nicht im
Repository.

## Noch nicht vorhandene Bereiche

Git-Historie, Remote, Releases und veröffentlichte Images entstehen erst in den
dafür vorgesehenen späteren Tasks.

## Ownership

| Bereich | Verantwortlich |
| --- | --- |
| Quellcode, Dokumentation und Reviews | GitHub-Repository |
| Image-Build und Provenienz | GitHub Actions nach MIG-009 |
| Versionierte Container-Artefakte | GHCR ab MIG-010 |
| Stackdefinition, Variablen und kontrollierter Cutover | Portainer |
| Persistenz, Secrets, Backups, Scheduler, Reverse Proxy und Firewall | Synology und Betreiber |
