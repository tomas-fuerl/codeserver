# Migrationsplan für tomas-fuerl/codeserver

## Ziel und Leitplanken

Der Codeserver-Bestand wird aus dem privaten Repository
`tomas-fuerl/Homelab` in das neue öffentliche Repository
`tomas-fuerl/codeserver` überführt. Das Zielrepository erhält eine neue
Git-Historie und wird nach Abschluss die einzige gepflegte Codeserver-Quelle.

Produktive Environment-Dateien, Secrets, Passwort-Hashes, Backups,
Restore-Testdaten, Logs sowie Portainer-, DSM-, Reverse-Proxy- und
Firewallzustände bleiben außerhalb von Git. Externe Aktionen werden
ausschließlich über `EXTERNAL-ACTIONS.md` gesteuert. Die Entscheidungen in
`DECISIONS.md` und das Arbeitsprotokoll in `CODEX-PROTOCOL.md` sind verbindlich.

## Zuständigkeitsmodell

### Im öffentlichen Repository

Das Zielrepository verantwortet:

- Dockerfile und reproduzierbare Toolchain;
- einen Portainer-tauglichen `compose.yaml`-Vertrag;
- ausschließlich öffentliche Beispielvariablen in `.env.example`;
- Backup-, Restore-, Verifikations- und unterstützende Betriebsskripte;
- CI-Prüfungen und den GHCR-Build-/Publish-Workflow;
- Synology-, Portainer-, Security-, Support- und Entwicklungsdokumentation;
- Extension-Manifest und bereinigte Reproduzierbarkeitsdaten;
- Security-Policy, Contribution-/Entwicklungsworkflow und Releaseprozess.

### Lokal auf Synology beziehungsweise in Portainer

`<SYNOLOGY_DOCKER_ROOT>` bezeichnet das lokal gewählte Docker-Datenverzeichnis
auf der Synology. Der tatsächliche absolute Pfad wird bei der Installation
festgelegt und bleibt außerhalb von Git.

| Lokaler Zustand | Zweck / Beispielpfad | Verantwortliches System | Backup erforderlich | Darstellung im Repository | Verweis aus Portainer |
| --- | --- | --- | --- | --- | --- |
| Persistenter Codeserver-Baum | Konfiguration, Daten und Workspace unter `<SYNOLOGY_DOCKER_ROOT>/codeserver` | Synology-Dateisystem | Ja; konsistent und verifiziert | Nur Platzhalterpfad und Mountvertrag | Bind-Mount auf `/config` |
| Secret-Verzeichnis | Geschützte Ablage unter `<SYNOLOGY_DOCKER_ROOT>/codeserver-secrets` | Synology, administriert als `root` | Ja; restriktiv und zusammen mit Restore-Verfahren | Nur Beispielpfad, Rechte und Zweck | Quelle für einen read-only Secret-Mount |
| Backup-Verzeichnis | Archive, Prüfsummen und Manifeste unter `<SYNOLOGY_DOCKER_ROOT>/codeserver-backups` | Synology-Aufgabenplaner und Dateisystem | Ja; mindestens zweite geschützte Kopie nach lokaler Richtlinie | Nur Platzhalter, Format und Retention-Regeln | Kein direkter Stack-Mount erforderlich |
| Restore-Testbereich | Nicht-produktive Extraktion unter `<SYNOLOGY_DOCKER_ROOT>/codeserver-restore-tests` | Synology-Dateisystem | Nein; Ergebnisse sind kontrolliert verwerfbar | Nur Beispielpfad und Schutzregeln | Kein Bezug zum Produktionsstack |
| Portainer-Variablen | Reale Stackwerte, beispielsweise Image-Version, UID/GID und lokale Parameter | Portainer | Ja; sicherer Konfigurationsexport ohne Secret-Leak | Nur Variablennamen und Beispielwerte | Stack-Environment beziehungsweise UI-Variablen |
| Reale Domain | Öffentlicher Hostname für den Dienst | DNS und DSM Reverse Proxy | Ja; Konfigurationsnachweis | Ausschließlich `codeserver.example.com` | Falls erforderlich über `PROXY_DOMAIN` als Portainer-Wert |
| UID und GID | Eigentümerabbildung für persistente Daten | Synology und Portainer | Ja, als Betriebsparameter | Nur neutrale Beispielwerte | `PUID` und `PGID` |
| Reverse Proxy | HTTPS-Terminierung und Weiterleitung zum Loopback-Port | Synology DSM | Ja; DSM-Konfiguration separat sichern | Nur Vertrag und Prüfanleitung | Stack veröffentlicht ausschließlich den vereinbarten lokalen Zielport |
| Firewall | Erlaubte Netze/Ports und abschließende Sperrregeln | DSM und Router/Firewall | Ja; Regelstand separat sichern | Nur Anforderungen und Testmatrix | Kein direkter Portainer-Wert |
| DSM-Aufgabenplaner | Regelmäßiger Aufruf des Backupskripts | Synology DSM | Ja; Aufgabe und Zeitplan exportieren/dokumentieren | Nur Beispielbefehl mit Platzhalterpfad | Kein direkter Stack-Verweis |
| Produktive Secret-Datei | Nicht leerer Passwort-Hash unter `<SYNOLOGY_DOCKER_ROOT>/codeserver-secrets/hashed_password` | Synology gemäß lokalem Administrationsmodell | Ja; ausschließlich geschützt, niemals im Bericht ausgeben | Kein Wert; nur Dateiname, Rechte und Mountziel | Read-only nach `/run/secrets/hashed_password`, referenziert über `FILE__HASHED_PASSWORD` |

Automatische Portainer-GitOps-Updates bleiben für den ersten Cutover
deaktiviert. Lokale Werte werden nicht aus den öffentlichen Platzhaltern
abgeleitet oder in diese zurückgeschrieben.

## Taskübersicht

| Task | Titel | Status | Abhängigkeiten | Geplante externe Gates |
| --- | --- | --- | --- | --- |
| MIG-001 | Migrationssteuerung und Bestandsaufnahme | COMPLETED | keine | keine für MIG-001 |
| MIG-002 | Sauberen eigenständigen Arbeitsbaum erzeugen | COMPLETED | MIG-001 `COMPLETED` | keine |
| MIG-003 | Repository-Struktur und Root-Layout erstellen | COMPLETED | MIG-002 | keine |
| MIG-004 | Synology- und Portainer-Vertrag fertigstellen | COMPLETED | MIG-003 | keine |
| MIG-005 | CI und GHCR-Publish-Workflow erstellen | COMPLETED | MIG-003, MIG-004 | keine |
| MIG-006 | Sicherheits- und Funktionsprüfung | COMPLETED | MIG-003 bis MIG-005 | EXT-010 `COMPLETED` |
| MIG-007 | Initial-Commit erstellen | READY_FOR_REVIEW | MIG-006 | ausdrückliche Commit-Freigabe |
| MIG-008 | Öffentliches GitHub-Repository anlegen | NOT_STARTED | MIG-007 | EXT-001 |
| MIG-009 | Push und GitHub-Sicherheit konfigurieren | NOT_STARTED | MIG-008, EXT-001 | initialer Push, EXT-002 |
| MIG-010 | Release und GHCR-Image erstellen | NOT_STARTED | MIG-009, EXT-002 | Release-Push/Workflow, EXT-003 |
| MIG-011 | Portainer-Teststack deployen | NOT_STARTED | MIG-010, gegebenenfalls EXT-003 | EXT-008, danach EXT-004 |
| MIG-012 | Produktiven Portainer-Cutover durchführen | NOT_STARTED | MIG-011, EXT-004 | EXT-005, EXT-006 |
| MIG-013 | Backup-, Restore- und Laufzeitabnahme | NOT_STARTED | MIG-012, EXT-005, EXT-006 | EXT-007 und lokale Betriebsabnahmen |
| MIG-014 | Codeserver aus Homelab entfernen | NOT_STARTED | MIG-013, EXT-007 | gegebenenfalls Homelab-PR/Push |
| MIG-015 | Migration abschließen | NOT_STARTED | MIG-014 | gegebenenfalls finale GitHub-/Betriebsprüfung |
| MIG-016 | GitHub CLI im code-server-Image bereitstellen | COMPLETED | veröffentlichter Repository-Ausgangsstand | EXT-012 `COMPLETED`, EXT-013 `COMPLETED` |
| MIG-017 | code-server-Image für SoSeBaMa-Entwicklung vorbereiten | BLOCKED | MIG-016 `COMPLETED`, EXT-014 `COMPLETED` | ungeklärte tatsächliche HIGH/CRITICAL-Befunde im PR-Image-Scan; Task bleibt BLOCKED |

`PENDING`-Einträge für spätere Tasks blockieren MIG-001 nicht. Sie werden zum
Gate, sobald ihr zugehöriger Task erreicht wird.

## MIG-001: Migrationssteuerung und Bestandsaufnahme

- **Status:** COMPLETED
- **Ziel:** Repositoryzustand und Codeserver-Artefakte inventarisieren sowie
  Plan, Zuständigkeiten, Entscheidungen und External-Action-Steuerung anlegen.
- **Abhängigkeiten:** Keine.
- **Erlaubte Änderungen:** Ausschließlich die fünf Migrationsdokumente unter
  `docs/migration/` und der ignorierte lokale Bericht `TASK-RESULT.md`.
- **Erwartete Artefakte:** Dieser Plan, `CODEX-PROTOCOL.md`,
  `EXTERNAL-ACTIONS.md`, `DECISIONS.md` und `tasks/MIG-001.md`.
- **Erforderliche Prüfungen:** Geforderte Git-Inventarisierung,
  Dateiklassifikation, `git diff --check`, `git status --short
  --untracked-files=all`, `git diff --stat` sowie Scope-, Branch-, Remote-,
  Historien- und Commitkontrolle.
- **Mögliche externe Aktionen:** Keine; spätere Aktionen werden nur geplant.
- **Abschlusskriterien:** Vollständige Dokumente, alle anderen Tasks
  `NOT_STARTED`, keine Produktdatei geändert und keine externe Aktion
  ausgeführt.
- **Rollback / Abbruchstrategie:** Nur die neu erstellten MIG-001-Dokumente
  verwerfen; vorhandene Benutzeränderungen unangetastet lassen. Bei notwendiger
  externer Aktion sicher stoppen und MIG-001 blockieren.

## MIG-002: Sauberen eigenständigen Arbeitsbaum erzeugen

- **Status:** COMPLETED
- **Ziel:** Einen history-freien, sanitisierten und strikt abgegrenzten
  Codeserver-Arbeitsbaum als Basis des Zielrepositorys erzeugen.
- **Abhängigkeiten:** MIG-001 muss nach Review `COMPLETED` sein.
- **Erlaubte Änderungen:** Nur ein neu freigegebenes Ziel-/Stagingverzeichnis;
  keine Änderung oder Löschung im Homelab-Quellbaum.
- **Erwartete Artefakte:** Whitelist-basierter Snapshot, Herkunftsmanifest und
  dokumentierte Ausschlussliste ohne alte `.git`-Daten.
- **Erforderliche Prüfungen:** Dateiliste gegen MIG-001-Inventar, keine
  Environment-/Secret-/Backup-/Logdateien, kein `.git`, Publication-Audit mit
  null Blocker/High/Incomplete und Syntaxprüfung exportierter Shell-Skripte.
- **Mögliche externe Aktionen:** Keine; kein Remote und kein Netzwerkzugriff.
- **Abschlusskriterien:** Zielbaum ist eigenständig, reviewbar, history-frei und
  enthält ausschließlich freigegebene Dateien.
- **Remediation 2:** Drei exportierte Shellskripte wurden anhand statisch
  bestandener Quellreferenzen repariert, ohne private Werte zu übernehmen.
  `bash -n` und ShellCheck bestehen für alle zehn Zielskripte; das unveränderte
  Publication-Audit meldet 0 Blocker, 0 High und 0 Incomplete.
- **Menschliches Review:** MIG-002 wurde nach erfolgreichem Publication-Audit,
  vollständig erfolgreicher Shellsyntax- und ShellCheck-Prüfung sowie
  bestätigter Privatwert- und Artefaktfreiheit genehmigt. MIG-003 ist
  freigegeben.
- **Rollback / Abbruchstrategie:** Unveröffentlichtes Stagingziel erhalten oder
  nach expliziter Freigabe entfernen; Quellbaum bleibt unverändert.

## MIG-003: Repository-Struktur und Root-Layout erstellen

- **Status:** COMPLETED
- **Ziel:** Den Snapshot in eine öffentliche Root-Struktur mit klaren
  Dokumentations-, Skript- und Workflowpfaden überführen.
- **Abhängigkeiten:** MIG-002.
- **Erlaubte Änderungen:** Ausschließlich im neuen eigenständigen Arbeitsbaum;
  Rootdateien, `docs/`, `scripts/`, `.github/` und zugehörige Beispiele.
- **Erwartete Artefakte:** Root-`Dockerfile`, `compose.yaml`, `.env.example`,
  `.gitignore`, Lizenz, README sowie Security-, Support- und
  Entwicklungsdokumentation.
- **Erforderliche Prüfungen:** Layout- und Linkprüfung, keine Legacy-/lokalen
  Dateien, Shellsyntax, Format/Lint soweit vorhanden und Publication-Audit.
- **Mögliche externe Aktionen:** Keine.
- **Abschlusskriterien:** Rootlayout entspricht dem Zielrepository und alle
  Platzhalter sind öffentlich unbedenklich.
- **MIG-003-Ergebnis:** Der Zielbaum besitzt genau eine strukturelle
  `compose.yaml`, die öffentliche Root- und Dokumentationsstruktur sowie
  keinen Workflow vor MIG-005. Alle geschützten Dateien sind hashidentisch;
  Shell-, Link-, Artefakt- und Publication-Audit-Gates sind erfolgreich.
  Funktionale Legacy-Pfadprüfungen im hashgeschützten
  `verify-installation.sh` sind als `MIG-004_REQUIRED` dokumentiert.
- **Menschliches Review:** Struktur und Rootlayout wurden als vollständig
  genehmigt. Der Zielbaum enthält genau eine Compose-Datei, keine
  Legacy-Deploymentskripte und vor MIG-005 keine Workflows. Das unveränderte
  Publication-Audit war erfolgreich; MIG-004 ist freigegeben.
- **Rollback / Abbruchstrategie:** Änderungen nur im neuen Arbeitsbaum
  zurücknehmen; unveränderten MIG-002-Snapshot als Ausgangspunkt behalten.

## MIG-004: Synology- und Portainer-Vertrag fertigstellen

- **Status:** COMPLETED
- **Ziel:** Einen einzigen produktionsnahen Compose-Vertrag und die Trennung
  zwischen öffentlicher Konfiguration und lokalem Zustand fertigstellen.
- **Abhängigkeiten:** MIG-003 und die Entscheidungen DEC-005, DEC-006 und
  DEC-009.
- **Erlaubte Änderungen:** `compose.yaml`, `.env.example`, zugehörige Skripte und
  Synology-/Portainer-Dokumentation im neuen Arbeitsbaum.
- **Erwartete Artefakte:** GHCR-basierter Portainer-Stackvertrag, Variablenmatrix,
  Mount-/Secret-Vertrag, Cutover- und Rollback-Runbook.
- **Erforderliche Prüfungen:** Statische Compose-Validierung ohne produktive
  Werte, nur erwartete Ports/Mounts, keine Klartextpasswortvariablen, immutable
  Image-Referenz und dokumentierte lokale Zuständigkeiten.
- **Mögliche externe Aktionen:** Keine Laufzeitänderung; Portainer wird noch
  nicht geöffnet oder verändert.
- **Abschlusskriterien:** Ein Reviewer kann den Stack ausschließlich mit lokalen
  Werten bereitstellen, ohne private Werte im Repository abzulegen.
- **MIG-004-Ergebnis:** Variablen-, Compose-, Mount-, Secret-, Synology- und
  Portainervertrag sind finalisiert. Dokumentation und Betriebsskripte sind
  statisch geprüft; Publication-Audit und Nicht-Scope-Hashvergleich bestehen.
  Es wurde keine externe oder produktive Aktion ausgeführt.
- **Menschliches Review:** Variablenvertrag und Compose-Vertrag wurden
  genehmigt. Die statische Validierung war erfolgreich; aktive
  Legacy-Verweise sind nicht vorhanden. MIG-005 ist freigegeben.
- **Rollback / Abbruchstrategie:** Bei offenem Vertragsproblem auf das geprüfte
  MIG-003-Layout zurückgehen; Produktionsstack bleibt unangetastet.

## MIG-005: CI und GHCR-Publish-Workflow erstellen

- **Status:** COMPLETED
- **Ziel:** Lokale Qualitätsgates und einen least-privilege Workflow für
  reproduzierbare `linux/amd64`-GHCR-Images definieren.
- **Abhängigkeiten:** MIG-003 und MIG-004; DEC-007 und DEC-008.
- **Erlaubte Änderungen:** `.github/workflows/`, CI-Konfiguration und
  Release-/Entwicklungsdokumentation im neuen Arbeitsbaum.
- **Erwartete Artefakte:** PR-CI, Release-Workflow, Tag-/Versionsvertrag,
  SBOM/Provenienzkonfiguration und dokumentierte Berechtigungen.
- **Erforderliche Prüfungen:** Workflow-Syntax, vollständige verifizierte Action-SHAs,
  least-privilege Permissions, neuer Image-Name, unveränderliche Tags und keine
  eingebetteten Credentials.
- **Mögliche externe Aktionen:** Keine Workflow-Ausführung in diesem Task.
- **Abschlusskriterien:** Workflows sind lokal reviewbar und können ohne
  private Repositoryannahmen ausgeführt werden.
- **MIG-005-Ergebnis:** Zwei lokal geparste Workflows, neun vollständig
  gepinnte Action-Verwendungen, least-privilege Berechtigungen, strikter
  SemVer- und Tagvertrag, SBOM sowie Digest-Attestation sind definiert. Alle
  statischen Gates und der Nicht-Scope-Hashvergleich bestehen; keine externe
  Aktion wurde ausgeführt.
- **Remediation 2:** Das Review bestätigte eine fehlende `.dockerignore` und
  einen aktiven beweglichen `MAJOR.MINOR`-Imagetag. Das Dockerfile besitzt
  keine lokalen `COPY`-/`ADD`-Eingaben. Eine restriktive Allowlist gibt deshalb
  ausschließlich `Dockerfile` und `.dockerignore` frei. Publishing erzeugt nur
  `MAJOR.MINOR.PATCH` und `sha-<full-commit>`; Validator-Negativtests weisen
  zusätzliche Tags, eine fehlende Allowlist und verbotene Freigaben zurück.
- **Remediation 3:** Die automatische `latest`-Tag-Erzeugung war zuvor durch
  `${{ format('{0}{1}=false', 'late', 'st') }}` obfuskiert; Ursache war eine zu
  grobe, wortbasierte Reviewprüfung. Der Workflow verwendet nun eindeutig
  `latest=false`. Der Validator prüft den Flavor-Block semantisch und lehnt
  fehlende, aktivierende oder dynamische Varianten sowie zusätzliche Tags ab.
  Der Image-Tagvertrag bleibt unverändert.
- **Rollback / Abbruchstrategie:** Workflowdateien deaktiviert lassen
  beziehungsweise nicht veröffentlichen; keine Registry-Artefakte erzeugen.

## MIG-006: Sicherheits- und Funktionsprüfung

- **Status:** COMPLETED
- **Ziel:** Den vollständigen neuen Arbeitsbaum vor Historie und Veröffentlichung
  gegen Sicherheits-, Syntax- und Funktionsanforderungen prüfen.
- **Abhängigkeiten:** MIG-003, MIG-004 und MIG-005.
- **Erlaubte Änderungen:** Remediation der dokumentierten internen Freeze-Blocker
  und redigierte lokale Prüfnachweise; keine Produktionsaktionen.
- **Erwartete Artefakte:** Vollständiger Freeze-Audit, Gitleaks-Nachweis,
  reproduzierbares Quellarchiv und External-Action-Gate für den lokalen Build.
- **Erforderliche Prüfungen:** Alle statischen Repository-, Workflow-, Shell-,
  Python-, YAML-, Compose-, Dockerfile-, Extension-, Dokumentations- und
  Publication-Gates sowie Gitleaks und reproduzierbares Archiv.
- **Externe Aktion:** EXT-011 ist `NOT_REQUIRED`; EXT-010 ist `COMPLETED`.
- **MIG-006-Ergebnis:** Sämtliche internen Prüfungen einschließlich acht
  Negativtests, Gitleaks v8.30.1, reproduzierbarem Quellarchiv und
  Freeze-Vergleich sind erfolgreich. Der reale Betreiber-Build, Inspect und
  Toolchain-Smoke-Test auf `amd64`/`linux` bestanden; das Testimage wurde
  entfernt und der Containerbestand blieb unverändert.
- **Menschliches Review:** MIG-006 wurde nach erfolgreichem internem
  Freeze-Audit, Publication-Audit, Gitleaks-Scan, reproduzierbarem Archiv und
  erfolgreich abgeschlossenem EXT-010 genehmigt. Build, Inspect und
  Toolchain-Smoke-Test bestanden; Testimage und Testdaten wurden bereinigt,
  der Containerbestand blieb unverändert. MIG-007 ist freigegeben.
- **Rollback / Abbruchstrategie:** Kein Commit und kein Dockerzugriff aus diesem
  Container; bei neuem Reviewbefund MIG-006 mit konkretem Blockgrund zurücksetzen.

## MIG-007: Initial-Commit erstellen

- **Status:** READY_FOR_REVIEW
- **Ziel:** Den freigegebenen, history-freien Arbeitsbaum als ersten Commit des
  neuen Repositorys festhalten.
- **Abhängigkeiten:** MIG-006 `COMPLETED` und ausdrückliche Commit-Erlaubnis.
- **Erlaubte Änderungen:** Lokale Git-Initialisierung beziehungsweise Staging
  und genau der freigegebene Initial-Commit im neuen Arbeitsbaum.
- **Erwartete Artefakte:** Neue Git-Historie mit genau einem reviewten Commit,
  ohne Remote und ohne alte Homelab-Objekte.
- **Erforderliche Prüfungen:** Stagingliste, Commitinhalt, Commitanzahl,
  `git status`, keine Environment-/Secret-Dateien, kein Remote und erneuter
  Publication-Audit des committed Standes.
- **Mögliche externe Aktionen:** Keine; Commit nur nach ausdrücklicher Freigabe.
- **Abschlusskriterien:** Genau ein lokaler Initial-Commit entspricht dem
  geprüften Scope und der Arbeitsbaum ist sauber.
- **MIG-007-Ergebnis:** Der ursprüngliche parentlose Root-Commit wurde
  erfolgreich erstellt. Sein einziges fehlerhaftes Post-Commit-Gate entstand,
  weil die rekursiven Python- und Shellprüfungen in
  `scripts/verify-installation.sh` auch `.git` als Projektbaum behandelten.
  Die direkten rekursiven Suchen in `validate-repository.sh` prunten
  `.git` bereits korrekt und blieben unverändert.
- **Remediation 2:** Eine zentrale Python-Pfadprüfung überspringt genau Pfade,
  deren erste relative Komponente `.git` ist. Die drei rekursiven
  Shell-`find`-Aufrufe verwenden entsprechend
  `-path "$REPOSITORY_ROOT/.git" -prune -o`. `.github`, `.gitignore`,
  `.dockerignore`, `.env.example` und alle anderen Projektdateien bleiben
  prüfpflichtig. Sechs temporäre Regressionstests bestanden: zwei positive
  `.git`-Ausschlusstests und vier Negativtests für Projekt-LF, `.github`,
  `stack.env` und Shellsyntax. Nach vollständig erfolgreichen Gates wird
  ausschließlich der unveröffentlichte Root-Commit genau einmal kontrolliert
  amended; MIG-008 bleibt `NOT_STARTED`.
- **Rollback / Abbruchstrategie:** Vor dem Commit abbrechen und Staging
  korrigieren. Nach dem Commit keine Historie ohne neue ausdrückliche Freigabe
  umschreiben.

## MIG-008: Öffentliches GitHub-Repository anlegen

- **Status:** NOT_STARTED
- **Ziel:** Das leere öffentliche Zielrepository ohne fremde Initialhistorie
  bereitstellen.
- **Abhängigkeiten:** MIG-007.
- **Erlaubte Änderungen:** Lokale Statusdokumentation; GitHub-Aktion ausschließlich
  durch EXT-001.
- **Erwartete Artefakte:** Bestätigtes leeres Repository
  `tomas-fuerl/codeserver` und redigierter Nachweis.
- **Erforderliche Prüfungen:** Eigentümer, Name, Sichtbarkeit, leerer Commit-/
  Branchzustand und keine automatisch erzeugten Dateien.
- **Mögliche externe Aktionen:** EXT-001.
- **Abschlusskriterien:** EXT-001 ist `COMPLETED`; URL und leerer Zielzustand sind
  belegt.
- **Rollback / Abbruchstrategie:** Kein Push. Falsch angelegtes leeres
  Repository durch den Eigentümer korrigieren oder nach Freigabe entfernen.

## MIG-009: Push und GitHub-Sicherheit konfigurieren

- **Status:** NOT_STARTED
- **Ziel:** Die neue Historie einmalig veröffentlichen und den Default-Branch
  sowie GitHub-Sicherheitsfunktionen schützen.
- **Abhängigkeiten:** MIG-008 und EXT-001 `COMPLETED`.
- **Erlaubte Änderungen:** Zielremote im neuen Repository, initialer Push und
  GitHub-Einstellungen nur nach dokumentierter externer Freigabe.
- **Erwartete Artefakte:** Öffentlicher Initialstand, korrektes Remote,
  geschützter Default-Branch und aktivierte verfügbare Security-Gates.
- **Erforderliche Prüfungen:** Remote ohne Credentials, identische Commit-ID
  lokal/remote, öffentliche Dateiliste, Branchschutz, Actions-Permissions,
  Secret Scanning und Push Protection.
- **Mögliche externe Aktionen:** Initialer Netzwerk-Push und EXT-002; der Push
  muss vor Ausführung im External-Action-Protokoll freigegeben sein.
- **Abschlusskriterien:** Push und EXT-002 sind nachgewiesen erfolgreich; kein
  zusätzlicher oder alter Ref wurde veröffentlicht.
- **Rollback / Abbruchstrategie:** Bei falschem Inhalt Veröffentlichung stoppen,
  Repository vorübergehend privat setzen und mit einem separaten Incident-/
  Bereinigungsplan fortfahren; kein Force-Push improvisieren.

## MIG-010: Release und GHCR-Image erstellen

- **Status:** NOT_STARTED
- **Ziel:** Ein versioniertes Release und das erste freigegebene, unveränderliche
  GHCR-Image erzeugen.
- **Abhängigkeiten:** MIG-009 und EXT-002 `COMPLETED`.
- **Erlaubte Änderungen:** Release-Metadaten, ausdrücklich freigegebener Tag/
  Push und GitHub-Actions-/GHCR-Aktionen.
- **Erwartete Artefakte:** Release-Tag, erfolgreicher Workflow, Image-Digest,
  SBOM/Provenienz und Package-Verknüpfung.
- **Erforderliche Prüfungen:** Tagformat, Commitbezug, Workflowlogs ohne Secrets,
  Plattformen, Image-Labels, Digest, unveränderlicher Tag und öffentlicher Pull.
- **Mögliche externe Aktionen:** Release-Tag-Push/Workflow und EXT-003.
- **Abschlusskriterien:** Image ist eindeutig dem freigegebenen Commit
  zugeordnet und für MIG-011 abrufbar.
- **Rollback / Abbruchstrategie:** Fehlgeschlagenes oder falsches Image nicht
  deployen; Package/Release kennzeichnen oder nach separater Freigabe entfernen,
  ohne ein bestehendes Versionstag zu überschreiben.

## MIG-011: Portainer-Teststack deployen

- **Status:** NOT_STARTED
- **Ziel:** Compose-, Image- und Betriebsvertrag isoliert in Portainer prüfen.
- **Abhängigkeiten:** MIG-010; EXT-003 abgeschlossen oder nachweislich nicht
  erforderlich.
- **Erlaubte Änderungen:** Ausschließlich der isolierte Teststack und dafür
  vorgesehene Testpfade/-werte über EXT-004.
- **Erwartete Artefakte:** Redigierte Teststack-Konfiguration, technische und
  fachliche Abnahme sowie getestete Rückbauanweisung.
- **Erforderliche Prüfungen:** Image-Digest, Health, Login, Terminal, Persistenz,
  Mounts, Ports, Logs, Neustartverhalten und keine Auswirkung auf Produktion.
- **Mögliche externe Aktionen:** EXT-008 als lokales Vorprüfungsgate, danach EXT-004.
- **Abschlusskriterien:** Testmatrix erfolgreich, Rollback möglich und
  Produktionsdaten unverändert.
- **Rollback / Abbruchstrategie:** Teststack stoppen/entfernen, Testdaten zur
  Diagnose erhalten und Produktionsstack nicht verändern.

## MIG-012: Produktiven Portainer-Cutover durchführen

- **Status:** NOT_STARTED
- **Ziel:** Den produktiven Stack kontrolliert auf das freigegebene GHCR-Image
  und neue Repository umstellen.
- **Abhängigkeiten:** MIG-011 und EXT-004 `COMPLETED`; aktuelles verifiziertes
  Backup und freigegebenes Wartungsfenster.
- **Erlaubte Änderungen:** Produktiver Portainer-Stack und DSM-Aufgabenpfad
  ausschließlich über EXT-005 und EXT-006.
- **Erwartete Artefakte:** Gesicherter Vorzustand, Cutoverprotokoll,
  Image-Digest, Health-/Fachabnahme und aktualisierte Backupaufgabe.
- **Erforderliche Prüfungen:** Backup vor Änderung, Stackdiff, automatische
  Updates aus, Image/Health/Login/Terminal/Persistenz/Mounts/Logs sowie
  erfolgreicher Scheduler-Test.
- **Mögliche externe Aktionen:** EXT-005 und EXT-006.
- **Abschlusskriterien:** Beide Aktionen `COMPLETED`, Produktion healthy und der
  alte Stack samt lokalem Rollbackimage weiterhin wiederherstellbar.
- **Rollback / Abbruchstrategie:** Sofort auf gesicherte Stackdefinition und
  `homelab-code-server:1.3.3` zurückgehen; keine persistenten Daten löschen.

## MIG-013: Backup-, Restore- und Laufzeitabnahme

- **Status:** NOT_STARTED
- **Ziel:** Den neuen produktiven Pfad einschließlich Backup, unabhängiger
  Verifikation, nicht-destruktivem Restore und Netzwerkzugang abnehmen.
- **Abhängigkeiten:** MIG-012, EXT-005 und EXT-006 `COMPLETED`.
- **Erlaubte Änderungen:** Freigegebene lokale Test-/Nachweisaktionen; keine
  Löschung von Backups, Restore-Daten oder Rollbackimages.
- **Erwartete Artefakte:** Redigierte Backup-, Verify-, Restore-, Runtime-,
  Reverse-Proxy- und Firewall-Abnahme.
- **Erforderliche Prüfungen:** Neues Backup, unabhängige Integrität,
  nicht-destruktiver Restore in Testpfad, Secret-Metadaten ohne Inhaltsausgabe,
  Container/Health/Login/Persistenz sowie EXT-007.
- **Mögliche externe Aktionen:** Lokale Betriebsprüfungen und EXT-007.
- **Abschlusskriterien:** Alle Abnahmen erfolgreich, Restrisiken akzeptiert und
  Rollbackbasis nachweislich intakt.
- **Rollback / Abbruchstrategie:** Bei Laufzeitfehler auf alten Stack wechseln;
  bei Backup-/Restorefehler MIG-013 blockieren und den neuen Stand nicht als
  alleinige Betriebsbasis akzeptieren.

## MIG-014: Codeserver aus Homelab entfernen

- **Status:** NOT_STARTED
- **Ziel:** Nach erfolgreicher Migration die Doppelpflege im privaten Homelab-
  Repository beenden.
- **Abhängigkeiten:** MIG-013 und EXT-007 `COMPLETED` sowie Betreiberfreigabe.
- **Erlaubte Änderungen:** Separat reviewte Entfernung des Codeserver-Quellbereichs
  und Anpassung ausschließlich betroffener Homelab-Verweise; keine Löschung
  lokaler Laufzeitdaten, Backups oder Images.
- **Erwartete Artefakte:** Homelab-Änderung mit Verweis auf das neue Repository
  und dokumentierter Ausschluss lokaler/persistenter Daten.
- **Erforderliche Prüfungen:** Dateidiff, verbleibende Referenzen, keine
  Environment-/Secret-Inhalte, Homelab-Checks und Bestätigung, dass das neue
  Repository vollständig ist.
- **Mögliche externe Aktionen:** Separater Homelab-PR/Push nach Freigabe.
- **Abschlusskriterien:** Kein zu pflegender Codeserver-Quellbestand verbleibt in
  Homelab; Produktion und Rollbackartefakte bleiben erhalten.
- **Rollback / Abbruchstrategie:** Änderung vor Merge verwerfen oder über einen
  normalen Revert-Change zurücknehmen; keine Historie umschreiben.

## MIG-015: Migration abschließen

- **Status:** NOT_STARTED
- **Ziel:** Steuerungsdokumente, Betriebshandover und verbleibende Risiken final
  abnehmen.
- **Abhängigkeiten:** MIG-014.
- **Erlaubte Änderungen:** Abschlussdokumentation und Statuspflege in den
  betroffenen Repositories; keine automatische Bereinigung lokaler Daten oder
  Images.
- **Erwartete Artefakte:** Abschlussbericht, finaler Task-/Decision-/External-
  Action-Stand, Betreiberübergabe und Backlog für optionale Verbesserungen.
- **Erforderliche Prüfungen:** Alle Tasks/Actions abgeschlossen, öffentliches
  Repository und GHCR erreichbar, Produktion healthy, Backup/Restore gültig,
  Support-/Security-Dokumente aktuell und keine Doppelpflege.
- **Mögliche externe Aktionen:** Finale GitHub-/Betriebsprüfung; jede notwendige
  Änderung erhält vorab einen `EXT`-Eintrag.
- **Abschlusskriterien:** Migration ist nachvollziehbar abgeschlossen und alle
  verbleibenden Risiken besitzen Eigentümer und Folgemaßnahme.
- **Rollback / Abbruchstrategie:** Bei offenem Gate MIG-015 nicht abschließen;
  produktive Rollbackbasis bis zur ausdrücklichen späteren Bereinigung erhalten.

## MIG-016: GitHub CLI im code-server-Image bereitstellen

- **Status:** COMPLETED
- **Ziel:** `gh` exakt gepinnt und offiziell checksum-verifiziert für `amd64`
  und `arm64` installieren, bestehende Werkzeugprüfungen erweitern und die
  manuelle persistente Betreiber-Authentifizierung sicher dokumentieren.
- **Abhängigkeiten:** Veröffentlichter Repository-Ausgangsstand; keine
  Abhängigkeit von den noch offenen historischen Cutover-Tasks.
- **Erlaubte Änderungen:** Dockerfile, bestehende Entwickler-, Toolchain- und
  statische Installationsprüfungen, unmittelbar relevante Dokumentation sowie
  MIG-016-Task- und External-Action-Nachweise.
- **Erwartete Artefakte:** Verifizierte `gh`-Installation, erweiterte Gates,
  deaktivierte GitHub-CLI-Telemetrie, korrigierte Node.js-Beschriftung und
  Betreiberanleitung ohne Credentials.
- **Erforderliche Prüfungen:** Repositoryvalidator, Bashsyntax, ShellCheck,
  `git diff --check`, CI-Build für `linux/amd64` und anschließend reale
  Container-, Werkzeug- und Persistenz-Smoke-Tests.
- **Mögliche externe Aktionen:** EXT-012 für offizielle Release-/Basisdaten;
  EXT-013 für Testcontainer, Laufzeit- und Persistenzabnahme.
- **Abschlusskriterien:** Lokaler Scope vollständig geprüft, keine Credentials
  aufgenommen und externe Nachweise wahrheitsgemäß dokumentiert.
- **Rollback / Abbruchstrategie:** Keine Version, Prüfsumme oder
  Persistenzannahme raten; Produktivsystem und bestehende Images unverändert
  lassen.
- **MIG-016-Ergebnis:** Lokale Implementierung und daemonfreie Gates sind
  erfolgreich. `gh 2.97.0` ist für `amd64` und `arm64` offiziell
  checksum-verifiziert; Entwickler-, Toolchain- und statische Gates wurden
  erweitert. GitHub Actions Lauf 5 hat Repositoryvalidator,
  Compose-Validierung und den nicht veröffentlichten `linux/amd64`-Image-Build
  für Commit `8d1088f4f53ec25bc4ffe82deeba0edc95f52dd2` erfolgreich ausgeführt.
  Der Betreiber hat EXT-013 mit dem veröffentlichten `linux/amd64`-Image
  `1.5.0` bei Digest
  `sha256:9f1db9f29b10b1eea956d1803fcade35c7bf75ef476ea43a03c1abddeddeb82b`
  abgeschlossen. Der isolierte Container war `running` und `healthy`;
  `gh 2.97.0`, `HOME=/config`, leere XDG-/GH-Konfigurations-Overrides,
  `GH_TELEMETRY=false` sowie die `/config`- und
  Authentifizierungspersistenz nach Neustart wurden bestätigt. Der bestehende
  code-server wurde durch den Betreiber auf die geprüfte Version aktualisiert.
  Codex führte weder Docker- noch Deployment- oder Anmeldeaktionen aus. Für
  die reine Abschlussdokumentation wurden Branch, Commit, Push und Draft-PR
  ausdrücklich freigegeben; Merge, Release, Tag und weiteres Deployment
  bleiben ausgeschlossen.

## MIG-017: code-server-Image für SoSeBaMa-Entwicklung vorbereiten

- **Status:** BLOCKED
- **Ziel:** Das bestehende digestfixierte LinuxServer-code-server-Image um die
  reproduzierbare, daemonlose SoSeBaMa-Systemtoolchain erweitern: pnpm
  `11.19.0`, PostgreSQL-18-Client `18.4-1.pgdg24.04+1`, Docker CLI
  `5:29.7.0-1~ubuntu.24.04~noble`, Compose V2
  `5.3.1-1~ubuntu.24.04~noble`, Buildx `0.36.0-1~ubuntu.24.04~noble` und
  Trivy `0.72.0`.
- **Abhängigkeiten:** MIG-016 `COMPLETED`; der Basisdigest
  `lscr.io/linuxserver/code-server:4.131.0-ls354@sha256:621d…bad7` wurde als
  aktueller öffentlicher Multiarch-Manifestdigest geprüft und ersetzt den zuvor
  geprüften `4.128.0-ls351`-Stand nach den ersten PR-CI-Befunden.
- **Erlaubte Änderungen:** `Dockerfile`, `.github/workflows/ci.yml`,
  vorhandene Toolchain-/Installations-/Repositoryprüfungen, der neue
  wiederverwendbare Einstieg `scripts/ci/run-trivy-scan.sh`, unmittelbar
  betroffene Entwickler-/Betreiberdokumentation, dieses Dokument, die
  `MIG-017`-Taskdatei und der lokale ignorierte `TASK-RESULT.md`.
  `.github/workflows/publish-image.yml`, `compose.yaml`, Portainer-, Secret-,
  Release- und Deploymentverträge bleiben unverändert.
- **Versionsvertrag:** DEC-011 gibt Node.js innerhalb der Hauptversion `24`
  und pnpm innerhalb der Hauptversion `11` frei. Die konkreten Versionen
  bleiben im Dockerfile exakt gepinnt und über Herstellerprüfsummen
  beziehungsweise npm-Registry-Integrität verifiziert. Sichere Patch- und
  Minor-Updates benötigen vollständige Quellen-, Integritäts-,
  Kompatibilitäts- und CI-Prüfung; Hauptversionswechsel benötigen eine neue
  Eigentümerentscheidung. Floating-Versionen und eine Abschwächung des
  HIGH-/CRITICAL-Gates bleiben ausgeschlossen.
- **Quellen- und Integritätsvertrag:** pnpm stammt aus npm und wird über die
  offizielle Registry-Integrity `sha512-eIHz7VkNRyxKlV4riLISF5ERYGbcyIy8o4SeybYPG7qm0syyIfqR2k4cZb7yvL43k2Wup6xTnHv4be3DobItzg==`
  geprüft. PGDG- und Docker-APT-Quellen verwenden dedizierte `signed-by`-
  Keyrings und die Fingerprints `B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8`
  beziehungsweise `9DC858229FC7DD38854AE2D88D81803C0EBFCD88`. Trivy stammt aus
  dem offiziellen Aqua-Security-Archiv; die Checksummenliste und die
  `amd64`-/`arm64`-Archive werden SHA-256-geprüft. Alle Quellen unterstützen
  Ubuntu Noble auf `amd64` und `arm64`; Lizenzen sind MIT (pnpm/Trivy) bzw.
  Apache-2.0-/PostgreSQL-Lizenz der offiziellen Paketquellen.
- **CI- und Sicherheitsvertrag:** Die PR-CI validiert unverändert alle
  Repositorygates, richtet QEMU über einen vollständigen Commit-SHA
  (`v4.2.0`) ein, baut beide Architekturen einschließlich Dockerfile-Smoke-
  Tests und startet nur auf `amd64` einen isolierten Container ohne Socket,
  Secrets oder produktive Mounts. Das wiederverwendbare Trivy-Skript scannt
  Repositorydateisystem/Konfiguration und die tatsächlich gebauten
  `amd64`-/`arm64`-Artefakte. Ungeklärte `HIGH`- oder `CRITICAL`-Befunde
  blockieren; `MEDIUM` und niedriger werden berichtet. Ein Herstellerpatch-
  mangel ist kein Ignore-Grund.
- **SoSeBaMa-Abgrenzung:** React, Vite, NestJS, TypeScript, Prisma, Vitest,
  Playwright, Testcontainers, Zod, Dexie, PDF.js, `react-konva`, `pg-boss`
  und qpdf werden nicht global installiert, sondern später im SoSeBaMa-
  Repository oder in dedizierten Anwendungs-/Prüfimages fixiert.
- **Abschlusskriterien:** Lokale Repository-, Shell-, Link-, Action-,
  Publication- und `git diff --check`-Gates sind erfolgreich; PR-CI weist
  beide Architekturen, Runtime-Smoke und alle Trivy-Scans nach; keine ungeklärten
  `HIGH`-/`CRITICAL`-Befunde; `TASK-RESULT.md` ist wahrheitsgemäß. Der Task
  endet höchstens mit `READY_FOR_REVIEW`; `COMPLETED` ist erst nach
  menschlicher Abnahme und Merge zulässig. Der aktuelle Status ist wegen der ungeklärten tatsächlichen PR-Imagebefunde
  `BLOCKED`; EXT-014 ist als `COMPLETED` dokumentiert und erlaubt nur die
  befristete Ausnahme `AVD-DS-0002` bis einschließlich `2026-10-31` für den
  LinuxServer-s6-Initvertrag.
  DEC-011 ist `ACCEPTED` und legt Node.js `24.x` sowie pnpm `11.x`
  als freigegebene Hauptversionslinien bei weiterhin exakten,
  integritätsgeprüften Build-Pins fest.
- **Rollback / Abbruchstrategie:** Bei nicht ausführbarer Prüfung oder einem
  nicht sicher behebbaren `HIGH`-/`CRITICAL`-Befund MIG-017 auf `BLOCKED`
  setzen, Befund und betroffene Schicht dokumentieren und keine Ignore-Regel
  einführen. Ein Rollback setzt den vorherigen freigegebenen Basis-/Image-
  Digest ein; produktive Systeme, Secrets und persistente Daten bleiben
  unangetastet.
