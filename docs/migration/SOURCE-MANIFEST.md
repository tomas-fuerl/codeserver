# Herkunftsmanifest des Codeserver-Snapshots

## Herkunft

| Merkmal | Wert |
| --- | --- |
| Quellrepository | `tomas-fuerl/Homelab` |
| Lokaler Quellpfad | `/config/workspace/Homelab` |
| Quellbranch | `chore/codeserver-consolidation-audit` |
| Quell-Commit | `dbff9a73b193268fd1ad69d5e657fdbb0b6b1c79` |
| Exportdatum | `2026-07-20T18:31:45Z` |
| Snapshot-Skript | `/config/workspace/Homelab/scripts/security/create-public-snapshot.sh` |

Der Snapshot wurde ohne `--init-git` erzeugt. Es wurde weder die alte
Git-Historie noch ein `.git`-Verzeichnis übernommen. Das Exportskript arbeitet
whitelist-basiert; die anschließend ergänzten Migrationsdokumente sind in
`TASK.md` für MIG-002 ausdrücklich freigegeben.

## Exportierte Dateien

Der vollständige Zielbaum umfasst nach Abschluss der Dokumentübernahme 32
reguläre Dateien:

- `.env.example`
- `.github/workflows/codeserver-image.yml`
- `.gitignore`
- `Dockerfile`
- `GHCR-RELEASE.md`
- `LICENSE`
- `README.md`
- `docker-compose.ghcr.yaml`
- `docker-compose.yaml`
- `docs/BACKUP-RESTORE.md`
- `docs/CURRENT-STATE.md`
- `docs/SECURITY.md`
- `docs/UPDATE-ROLLBACK.md`
- `docs/migration/CODEX-PROTOCOL.md`
- `docs/migration/DECISIONS.md`
- `docs/migration/EXTERNAL-ACTIONS.md`
- `docs/migration/MIGRATION-PLAN.md`
- `docs/migration/SOURCE-MANIFEST.md`
- `docs/migration/tasks/MIG-001.md`
- `docs/migration/tasks/MIG-002.md`
- `extensions.lock.txt`
- `extensions.txt`
- `scripts/backup-config.sh`
- `scripts/deploy-update.sh`
- `scripts/restore-config.sh`
- `scripts/rollback-update.sh`
- `scripts/security/publication-audit.sh`
- `scripts/sync-extensions.sh`
- `scripts/verify-backup.sh`
- `scripts/verify-developer-tools.sh`
- `scripts/verify-installation.sh`
- `scripts/verify-toolchain.sh`

## Ausgeschlossene Kategorien

- `.git`, Git-Objekte und Git-Refs;
- Environment-Dateien außer `.env.example`, insbesondere `.env`, `stack.env`,
  `*.env` und `.env.*`;
- Secrets und andere vertrauliche Werte;
- Passwort-Hashes;
- Backups;
- Restore-Daten;
- Logs;
- Archive;
- Datenbanken;
- Schlüssel;
- Zertifikate;
- produktive Portainer-Werte;
- DSM-Konfiguration;
- Firewall-Konfiguration;
- Reverse-Proxy-Konfiguration;
- benutzerspezifische, nicht von der Whitelist freigegebene Konfiguration.

## Bekannte nicht übernommene lokale Dateien

- `codeserver/.env`;
- `codeserver/stack.env`.

Die Inhalte dieser lokalen Dateien wurden nicht gelesen oder ausgegeben.
`codeserver/codex/config.toml` wurde ebenfalls nicht übernommen, weil es im
MIG-001-Inventar als `REVIEW_REQUIRED` klassifiziert ist.

## Sanitization performed during MIG-002 Remediation 1

- Eine private Domainkennung aus optionalen Extension-Metadaten wurde durch
  einen neutralen öffentlichen Platzhalter ersetzt.
- Produktive absolute Synology-Pfade wurden durch
  `<SYNOLOGY_DOCKER_ROOT>` ersetzt.
- Extension-IDs, Versionen und vorhandene Prüfsummen wurden nicht geändert.
- Secret- und Environment-Dateien wurden nicht gelesen.
- Es wurde keine Git-Historie übernommen.

## MIG-002 Remediation 2

- Durch die Snapshot-Sanitisierung entstandene Shellschäden wurden in
  `scripts/backup-config.sh`, `scripts/restore-config.sh` und
  `scripts/verify-installation.sh` minimal repariert.
- Referenz waren ausschließlich die mit `bash -n` und ShellCheck bestandenen
  privaten Quellskripte; die Quellskripte selbst blieben unverändert.
- Private Pfade, Domains, IP-Adressen und Repositorywerte wurden nicht
  zurückübernommen. Lokale Installationswerte verwenden gequotete
  Environment-Variablen mit `CHANGE_ME`-Sentinel und frühem Abbruch.
- Es wurden keine produktiven, Docker-, Backup-, Restore- oder
  Deploymentkommandos ausgeführt.
- Es wurde keine Git-Historie übernommen.

## Prüfstatus

- Snapshot-Erstellung: erfolgreich; keine Git-Initialisierung und keine
  übernommene Git-Historie;
- Remediation 1: private Domainmetadaten und produktive absolute
  Synology-Pfade sanitisiert;
- Remediation 2: drei exportierte Shellskripte anhand statisch bestandener
  Quellreferenzen minimal repariert; Quellskripte unverändert;
- `bash -n`: 10 von 10 Skripten erfolgreich;
- ShellCheck: 10 von 10 Skripten erfolgreich, 0 Diagnosen;
- Publication-Audit: Blocker 0, High 0, Incomplete 0, Exit-Code 0;
- Privatwert- und Artefaktprüfung: keine realen privaten Werte und keine
  verbotenen Artefakte;
- Nicht-Scope-Hashvergleich: identisch;
- finales Inventar: 32 reguläre Dateien;
- MIG-002-Status: `READY_FOR_REVIEW`; externe Aktionen: `NOT_REQUIRED`.

Alle vorgesehenen statischen Prüfungen wurden erfolgreich ausgeführt.
Produktive Laufzeit-, Docker-, Backup-, Restore- oder Deploymentprüfungen
waren nicht Teil dieser Remediation und wurden nicht ausgeführt. Es wurden
keine Secret-Werte oder Trefferinhalte ausgegeben und keine Secret- oder
Environment-Dateien gelesen.

## MIG-003 Repository restructuring

Der bestehende history-freie Zielbaum wurde in die Rootstruktur des
eigenständigen öffentlichen Repositorys überführt. Er wurde weder gelöscht
noch neu erzeugt und weiterhin nicht als Git-Repository initialisiert.

### Dateiumbenennungen und Zusammenführungen

- Die beiden bisherigen Compose-Varianten wurden intern verglichen und in
  genau eine strukturelle `compose.yaml` überführt. Grundlage war die
  GHCR-orientierte Variante; Healthcheck, Logbegrenzung, Stop-Grace-Period,
  Restart-Policy, Loopback-Bindung und read-only Secret-Mount wurden aus der
  lokalen Variante berücksichtigt.
- Die allgemeingültige Security-Dokumentation wurde als Root-`SECURITY.md`
  neu gefasst.
- Stabile Architekturinformationen wurden nach `docs/ARCHITECTURE.md`
  überführt.
- Allgemeine Releasegrundsätze wurden nach `docs/RELEASES.md` überführt.

### Entfernte Legacy-Dateien

- beide bisherigen Compose-Varianten;
- die bisherige Root-Releasedokumentation;
- die bisherigen Current-State- und Security-Dokumente unter `docs/`;
- die beiden lokalen Deploymentskripte;
- der alte Workflowentwurf.

Es wurde kein Platzhalterworkflow angelegt. CI und Publish-Workflow werden in
MIG-005 neu erstellt.

### Neue öffentliche Grunddokumente

Neu hinzugekommen sind `AGENTS.md`, `CONTRIBUTING.md`, `SECURITY.md`,
`SUPPORT.md`, `docs/ARCHITECTURE.md`, `docs/RELEASES.md`,
`docs/REPOSITORY-LAYOUT.md` und der Nachweis
`docs/migration/tasks/MIG-003.md`.

`README.md`, `docs/BACKUP-RESTORE.md` und
`docs/UPDATE-ROLLBACK.md` wurden auf die eigenständige öffentliche Struktur
und die Trennung von Repository- und lokalem Betreiberzustand ausgerichtet.

### Unveränderte funktionale Dateien

Dockerfile, Lizenz, beide Extension-Dateien, alle verbliebenen funktionalen
Shellskripte und das Publication-Audit blieben inhaltlich unverändert. Ihre
vor und nach MIG-003 ermittelten SHA-256-Hashlisten waren vollständig
identisch; die temporären Hashlisten wurden anschließend entfernt.

### Offene Folgetasks

- MIG-004 finalisiert Imageversion, Variablennamen, Mountquellen,
  Secretquelle, Portainerwerte, lokale Pfade und Compose-Validierung. Dazu
  gehört auch die funktionale Migration verbliebener Legacy-Pfadprüfungen im
  hashgeschützten Installationsprüfskript.
- MIG-005 erstellt CI und den GHCR-Build-/Publish-Workflow neu.

MIG-004 und MIG-005 wurden nicht begonnen. Es wurden keine alte Git-Historie,
keine externen oder produktiven Aktionen und keine lokalen Environment- oder
Secret-Dateien übernommen.


## MIG-004 Synology and Portainer contract

MIG-004 finalisiert den öffentlichen Installations- und
Konfigurationsvertrag, ohne den history-freien Zielbaum als Git-Repository zu
initialisieren.

### Finalisierte Variablennamen

Der Portainer-/Compose-Vertrag verwendet:

- `CODESERVER_IMAGE_REPOSITORY`, `CODESERVER_IMAGE_TAG` und
  `CODESERVER_CONTAINER_NAME`;
- `CODESERVER_BIND_ADDRESS` und `CODESERVER_HOST_PORT`;
- `CODESERVER_CONFIG_PATH`, `CODESERVER_SECRET_FILE`,
  `CODESERVER_BACKUP_PATH` und `CODESERVER_RESTORE_PATH`;
- `PUID`, `PGID`, `TZ` und `PROXY_DOMAIN`.

Betriebsskripte erhalten ausschließlich die explizit zugeordneten Rootwerte
`CODESERVER_CONFIG_ROOT`, `CODESERVER_SECRET_ROOT`,
`CODESERVER_BACKUP_ROOT`, `CODESERVER_RESTORE_ROOT` und den
`CODESERVER_CONTAINER_NAME`. Es werden keine produktiven Environment-Dateien
automatisch geladen.

### Finalisierte Compose-Datei

`compose.yaml` enthält genau den Dienst `code-server` mit:

- dem Imagevertrag
  `ghcr.io/tomas-fuerl/codeserver:<CODESERVER_IMAGE_TAG>`;
- verpflichtendem explizitem Image-Tag ohne `latest`;
- Loopback-Portdefault `127.0.0.1:8377`;
- `/config`-Bind-Mount;
- read-only Secret-Mount nach `/run/secrets/hashed_password`;
- festem `FILE__HASHED_PASSWORD`-Dateiverweis;
- funktionalem lokalen Healthcheck, begrenztem JSON-Logging,
  `restart: unless-stopped` und `stop_grace_period: 30s`;
- keinem Buildvertrag und keiner Klartextpasswortvariable.

Die statische Interpolation und YAML-Struktur wurden mit öffentlichen
Testwerten und dem lokal vorhandenen Parser `CPAN::Meta::YAML` validiert.
`docker compose` war lokal nicht verfügbar; es wurde kein Paket installiert.

### Betreiberanleitung und Skriptrefactoring

Neu sind `docs/CONFIGURATION.md` und `docs/SYNOLOGY-PORTAINER.md`.
README, Architektur, Repository-Layout, Backup-/Restore- sowie
Update-/Rollbackdokumentation verweisen auf den finalen Vertrag.

Backup und Restore verlangen explizite absolute, getrennte Rootpfade und
brechen bei fehlenden beziehungsweise `CHANGE_ME`-Werten vor Datei- oder
Dockeroperationen ab. `scripts/verify-installation.sh` trennt `--static`,
`--runtime` und `--all`; ohne Argument wird ausschließlich `--static`
ausgeführt.

### Zustands- und Aktionsgrenzen

Alle Pfade, Domains, UID/GID- und Imagewerte im öffentlichen Vertrag sind
öffentliche Beispiele. Es wurden keine produktiven Werte, Secret-Inhalte,
lokalen Environment-Dateien oder private Infrastrukturinformationen
übernommen.

MIG-004 führte keine externe Aktion, keine Runtimeprüfung, keinen Build, Pull,
Containerstart, Backup, Restore oder Deployment aus. Der Zielbaum besitzt
weiterhin keine Git-Historie, kein Remote und keinen Commit. CI- und
Publish-Workflows bleiben MIG-005 vorbehalten.

## MIG-005 CI and GHCR workflows

MIG-005 ergänzt zwei neu erstellte GitHub-Actions-Workflows, drei lokale
CI-Prüfer, Dependabot- und Pull-Request-Konfiguration sowie den öffentlichen
CI-/Releasevertrag. Alle externen Actions sind auf vollständige, am
2026-07-21 über die offiziellen Release- und Commitseiten verifizierte
Commit-SHAs gepinnt.

CI validiert den Repository- und Compose-Vertrag und baut ausschließlich
`linux/amd64` ohne Registry-Login, Load oder Push. Publishing ist nur über
einen strikten Tag `vMAJOR.MINOR.PATCH` möglich, verwendet ausschließlich
das `GITHUB_TOKEN`, erzeugt vollständigen Patch- und langes SHA-Imagetag,
eine SBOM sowie eine Digest-gebundene Provenienz-Attestation. Bewegliche
Minor-/Major-, Branch-/Ref- und automatische Standardtags werden nicht erzeugt.

Der Zielbaum wurde nicht als Git-Repository initialisiert. Es wurde kein
Workflow ausgeführt, kein Image gebaut oder veröffentlicht und keine externe
oder produktive Aktion vorgenommen. MIG-006 bleibt `NOT_STARTED`.


## MIG-005 Remediation 2

Die Reviewbefunde waren im geprüften Zielbaum tatsächlich vorhanden:
`.dockerignore` fehlte vollständig, und die aktive Metadata-Konfiguration
enthielt zusätzlich `type=semver,pattern={{major}}.{{minor}}`. Das Dockerfile
enthält keine lokalen `COPY`- oder `ADD`-Anweisungen und benötigt daher keine
lokalen Buildquellen.

Die neue Buildkontext-Allowlist besteht ausschließlich aus globalem Ausschluss
sowie den Freigaben für `Dockerfile` und `.dockerignore`. Dokumentation,
Migrationsdaten, Repository-Metadaten, lokale Environment-Dateien und andere
verbotene Kategorien bleiben ausgeschlossen. `.gitignore` und `.dockerignore`
erfüllen getrennte Git- beziehungsweise Buildkontextaufgaben.

Der finale Publish-Vertrag erzeugt aus `vMAJOR.MINOR.PATCH` ausschließlich
`MAJOR.MINOR.PATCH` und `sha-<full-commit>`. Der vorherige bewegliche
`MAJOR.MINOR`-Tag wurde entfernt. Die Validatoren erzwingen exakt zwei aktive
Metadata-Tagdefinitionen und die exakte Buildkontext-Allowlist; lokale
Negativtests bestätigten die Ablehnung zusätzlicher Tags, einer fehlenden
`.dockerignore` und verbotener Allowlistfreigaben. Es wurde kein Workflow,
Docker-Build, GitHub-Schreibzugriff oder Produktionseingriff ausgeführt.

Die vollständigen Remediation-2-Gates bestanden ohne Workflow- oder
Docker-Ausführung. MIG-005 ist `READY_FOR_REVIEW`; MIG-006 bleibt
`NOT_STARTED`.

## MIG-005 Remediation 3

Vor Remediation 3 war die Deaktivierung der automatischen Tag-Erzeugung als
`${{ format('{0}{1}=false', 'late', 'st') }}` dynamisch und obfuskiert
zusammengesetzt. Ursache war eine zu grobe, wortbasierte Reviewprüfung.

Final verwendet `docker/metadata-action` den eindeutigen Flavor
`latest=false`. Es gibt weder Stringverkettung noch dynamische Expression;
aktiv bleiben ausschließlich Patch-SemVer und der lange Commit-SHA.

Der aktualisierte Actions-Validator verlangt genau einen aktiven
`flavor`-Block, genau eine effektive Zeile und dort exakt `latest=false`.
Fehlende, aktivierende oder dynamische Flavor-Werte und zusätzliche
Tagdefinitionen werden semantisch abgewiesen.

Die fünf Negativtests für `latest=auto`, `latest=true`, fehlenden Flavor,
dynamische Expression und `type=raw,value=latest` wurden auf temporären Kopien
erwartungsgemäß abgewiesen; der produktive Workflow bestand anschließend.

Alle vollständigen Gates bestanden: beide Validatoren, Bashsyntax für 10/10
Skripte, ShellCheck ohne Diagnosen, statische Installation mit 0 FAIL und
0 WARN, Markdown-Links sowie Publication-Audit mit 0 Blocker, 0 High und
0 Incomplete. Es wurde kein Workflow oder Docker-Build ausgeführt, kein
Repository initialisiert, kein Commit erstellt und keine externe Aktion
vorgenommen. MIG-005 ist `READY_FOR_REVIEW`; MIG-006 bleibt `NOT_STARTED`.

## MIG-006 pre-publication freeze audit

MIG-005 wurde nach menschlichem Review auf `COMPLETED` gesetzt. Der
history-freie Zielbaum wurde mit 46 regulären Dateien, 13 Rootdateien,
2 Workflows, 10 Shellskripten, 1 Python-Skript, 24 Markdown-Dateien und
4 YAML-Dateien eingefroren. Symlinks, leere Dateien, Dateien über 5 MiB und
verbotene Artefakte wurden nicht gefunden.

Erfolgreich waren beide Repositoryvalidatoren, Bashsyntax, ShellCheck,
Python-Compile, Markdown-Linkprüfung, YAML- und Workflowprüfung, zweifach
byteidentisches statisches Compose-Rendering, der `.dockerignore`-Negativtest
und das Publication-Audit mit 0 Blocker, 0 High und 0 Incomplete.

Der Audit ist dennoch `BLOCKED`: `scripts/security/publication-audit.sh` ist
nicht ausführbar; `Dockerfile` und `scripts/verify-toolchain.sh` enden nicht
mit einem Zeilenumbruch. Das Dockerfile besitzt ein bewegliches
`latest`-Basisimage, nicht nachvollziehbare Beispiel-/Homelab-Quellen und
keine nachgewiesene versionierte LinuxServer-Basis. `extensions.lock.txt`
enthält eine ungültige Nicht-Extension-Zeile; `scripts/sync-extensions.sh`
verwendet nicht `extensions.lock.txt`.

Gitleaks war lokal nicht vorhanden. Ausschließlich der offizielle
Release-Metadatensatz wurde read-only aufgelöst (`v8.30.1`, `linux_x64`);
Download und Ausführung der Drittanbieter-Binary waren nicht autorisiert.
EXT-011 steuert den ausstehenden spezialisierten Secret-Scan. Wegen der
internen Fehler wurde EXT-010 nicht angefordert; MIG-007 bleibt
`NOT_STARTED`. Funktionale Dateien wurden nicht verändert, kein Docker-Daemon
verwendet, kein Repository initialisiert und kein Commit erstellt.

## MIG-006 Remediation 1 und finaler interner Freeze

Die beschädigte Snapshot-Dockerfile wurde anhand der öffentlichen Upstreams
rekonstruiert. Die bereits verwendete LinuxServer-Version `4.128.0-ls351` ist
unter `lscr.io/linuxserver/code-server` mit dem offiziell nachgewiesenen
SHA-256-Manifest-Digest gepinnt. Node 24.18.0 und PowerShell 7.6.3 verwenden
ihre offiziellen Releasequellen und SHA-256-Prüfungen; pnpm 10.13.1 und Codex
0.144.5 bleiben exakt über die öffentliche npm-Registry gepinnt. Keine private
Quelle wurde zurückübernommen.

`extensions.lock.txt` enthält neun gültige, explizit versionierte Einträge ohne
Metadatenzeile. `scripts/sync-extensions.sh` verwendet standardmäßig exakt die
Root-Lockdatei und akzeptiert nur einen absoluten Override. Der Publication-Audit
ist ausführbar; alle Textdateien enden mit LF.

Der vollständige interne Audit einschließlich statischer Validatoren, acht
Negativtests, Gitleaks v8.30.1 mit verifiziertem Manifest und Archiv sowie zwei
byteidentischen deterministischen Quellarchiven ist erfolgreich. EXT-011 ist
`NOT_REQUIRED`; EXT-010 ist für den außerhalb des Containers auszuführenden
lokalen Build- und Toolchain-Smoke-Test `PENDING`. MIG-007 wurde nicht begonnen.

## MIG-006 EXT-010 completion

Der zuvor ausstehende externe Abschlussnachweis wurde durch den Betreiber
erfolgreich erbracht und menschlich genehmigt. Der reale Docker-Build für
`codeserver:mig006-local`, Image-Inspect und Toolchain-Smoke-Test endeten mit
Exit-Code 0 auf `amd64`/`linux`. Verifiziert wurden code-server 4.128.0 mit
Commit `cb22f74650a539d6f824d5944ec34d9e74844f66` und Code 1.128.0, Node
24.18.0, pnpm 10.13.1, PowerShell 7.6.3 und Codex CLI 0.144.5.

Der erste Zwischenlauf verwendete ausschließlich einen falschen Binary-Pfad;
der maßgebliche erfolgreiche Abschlusslauf verwendete
`/app/code-server/bin/code-server`. Das temporäre Testimage wurde mit
Exit-Code 0 entfernt. Es wurden keine Ports, Mounts oder Secrets verwendet,
kein Image gepusht und keine produktiven Container verändert. Der
Containerbestand blieb unverändert.

Der interne Freeze-Audit, Gitleaks, das reproduzierbare Archiv und der
Freeze-Vergleich waren bereits erfolgreich. Seit dieser finalen Freeze-Baseline
blieb der funktionale Zielbaum unverändert; für den MIG-006-Abschluss wurden
ausschließlich die freigegebenen Migrations- und Nachweisdokumente angepasst.
EXT-010 ist `COMPLETED`, EXT-011 `NOT_REQUIRED`; kein technischer Blocker bleibt. MIG-006 ist `READY_FOR_REVIEW`, MIG-007 bleibt `NOT_STARTED`.

## MIG-007 initial repository commit

Der Zielbaum wird für MIG-007 als vollständig neues Git-Repository mit einem
parentlosen Root-Commit auf Branch `main` initialisiert. Es werden weder die
Homelab-Historie noch alte Git-Objekte, Refs, Tags oder Remotes übernommen.

Der Commit umfasst ausschließlich den aktuell geprüften öffentlichen Zielbaum.
Produktive Environment-, Secret-, Authentifizierungs-, Backup-, Restore-,
Log-, Archiv-, Datenbank-, Schlüssel- und Zertifikatsdateien bleiben
ausgeschlossen; `.env.example` ist ausschließlich ein öffentliches Beispiel.
Der tatsächliche Commit-SHA wird nicht in den committed Zielbaum nachgetragen.

## MIG-007 Remediation 2

Der ursprüngliche Root-Commit wurde erfolgreich erstellt. Der einzige
Post-Commit-Blocker war die Erfassung interner Dateien unter `.git` durch die
rekursiven Python- und Shellprüfungen in
`scripts/verify-installation.sh --static`. Die direkten rekursiven
`find`-Suchen in `scripts/ci/validate-repository.sh` schlossen `.git`
bereits korrekt aus und wurden nicht geändert.

Die Python-Rekursion überspringt jetzt genau Pfade, deren erste relative
Komponente `.git` ist. Drei rekursive Shell-`find`-Aufrufe prunen
ausschließlich `$REPOSITORY_ROOT/.git`. `.github`, `.gitignore`,
`.dockerignore`, `.env.example` und alle anderen versteckten
Projektdateien bleiben prüfpflichtig.

Alle sechs Regressionstests bestanden: eine defekte Textdatei und ein
syntaktisch ungültiges Shellskript unter `.git` wurden ignoriert; eine
defekte reguläre Projektdatei, eine defekte Datei unter `.github`,
`stack.env` und ein ungültiges reguläres Shellskript wurden weiterhin
erkannt. Der unveröffentlichte Root-Commit wird nach erfolgreichen Gates genau
einmal kontrolliert amended. MIG-008 bleibt `NOT_STARTED`.
