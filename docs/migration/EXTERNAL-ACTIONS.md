# External-Action-Protokoll

Dieses Protokoll beschreibt geplante Aktionen außerhalb des verfügbaren
Containers und Repository-Arbeitsbaums. In MIG-005 wurde keine dieser Aktionen
ausgeführt. Alle Einträge sind `PENDING`, blockieren aber erst dann, wenn der
jeweils zugehörige Migrationstask oder das ausdrücklich genannte Gate erreicht
wird.

## EXT-001: GitHub-Repository tomas-fuerl/codeserver anlegen

- **Status:** PENDING
- **Zugehöriger Task:** MIG-008
- **Verantwortlich:** Repository-Eigentümer
- **Warum extern:** Das Repository muss im GitHub-Konto über GitHub angelegt
  werden; der lokale Arbeitsbaum kann diesen Zustand nicht erzeugen oder
  verifizieren.
- **Voraussetzungen:** MIG-007 ist abgeschlossen; der freigegebene Initialstand
  besitzt eine neue Historie; Name, Lizenz und öffentliche Sichtbarkeit sind
  bestätigt; der Publication-Audit ist ohne Blocker abgeschlossen.
- **Exakte Schritte:** In der GitHub-Organisation beziehungsweise im Konto
  `tomas-fuerl` ein leeres Repository `codeserver` mit Sichtbarkeit `Public`
  anlegen. Keine README-, Lizenz- oder `.gitignore`-Vorlage und keinen
  Initial-Commit erzeugen. Standardberechtigungen und erzeugte Repository-URL
  prüfen und dokumentieren.
- **Erwartetes Ergebnis:** Ein leeres öffentliches Repository
  `tomas-fuerl/codeserver` ohne fremde Initialhistorie ist vorhanden.
- **Benötigter Nachweis:** Repository-URL, Sichtbarkeit, leerer Branch-/Commit-
  Zustand und Zeitpunkt der Anlage; keine Tokens oder Zugangsdaten im Nachweis.
- **Rollback:** Solange noch nichts gepusht wurde, Repository nach gesonderter
  Freigabe wieder löschen oder auf `Private` setzen und die Ursache klären.
- **Freigabe für Folgetask:** MIG-009 erst nach Status `COMPLETED` und bestätigtem
  leeren Zielrepository beginnen.

## EXT-002: GitHub-Branchschutz und Security-Einstellungen aktivieren

- **Status:** PENDING
- **Zugehöriger Task:** MIG-009
- **Verantwortlich:** Repository-Eigentümer
- **Warum extern:** Rulesets, Schutzregeln und Security-Funktionen sind
  GitHub-seitige Einstellungen.
- **Voraussetzungen:** EXT-001 ist abgeschlossen; der geprüfte Initialstand ist
  auf dem vorgesehenen Default-Branch vorhanden; CI-Namen und erforderliche
  Checks sind bekannt.
- **Exakte Schritte:** GitHub Actions für das Repository erlauben und bevorzugt
  ausschließlich GitHub-Actions sowie verifizierte Docker-Actions zulassen.
  Vollständige Action-SHA-Pins verlangen, soweit die Oberfläche dies
  unterstützt. Workflowberechtigungen standardmäßig auf read-only setzen und
  deaktivieren, dass Actions Pull Requests erstellen oder genehmigen. Den
  Default-Branch kontrollieren. In MIG-009 ein Ruleset beziehungsweise
  Branchschutz mit Pull-Request-Pflicht, erforderlichen CI-Checks, Schutz vor
  Force-Push und Löschung sowie angemessener Review-Pflicht konfigurieren.
  Secret Scanning, Push Protection und Dependency-/Security-Alerts soweit für
  das Repository verfügbar aktivieren. Einstellungen anschließend erneut
  lesen.
- **Erwartetes Ergebnis:** Der Default-Branch ist gegen direkte riskante
  Änderungen geschützt und die verfügbaren Security-Funktionen sind aktiv.
- **Benötigter Nachweis:** Export oder Screenshots der Regeln und Security-
  Schalter sowie ein dokumentierter Test beziehungsweise GitHub-Status; keine
  sensiblen Benutzer- oder Tokenwerte.
- **Rollback:** Vorherige Einstellungen dokumentiert wiederherstellen, falls
  Regeln legitime Wartung blockieren; Schutz nicht stillschweigend abschalten.
- **Freigabe für Folgetask:** MIG-010 erst nach Status `COMPLETED` und
  nachgewiesenen Schutz-/Security-Einstellungen beginnen.

## EXT-003: GHCR-Package auf Public stellen, falls erforderlich

- **Status:** PENDING
- **Zugehöriger Task:** MIG-010
- **Verantwortlich:** Repository-Eigentümer
- **Warum extern:** Package-Sichtbarkeit und Verknüpfung werden in GHCR/GitHub
  verwaltet.
- **Voraussetzungen:** MIG-009 und EXT-002 sind abgeschlossen; der Release-
  Workflow hat das erwartete unveränderliche Versionsimage erzeugt; Digest und
  Herkunft wurden geprüft.
- **Exakte Schritte:** Nach dem ersten Publish in den Package-Einstellungen die Repository-Verknüpfung,
  Berechtigungsvererbung und aktuelle Sichtbarkeit prüfen. Nur falls das Package
  nicht öffentlich abrufbar ist, die Sichtbarkeit auf `Public` setzen. Das
  exakte Versionstag und den Digest anschließend ohne Authentifizierung lesend
  prüfen.
- **Erwartetes Ergebnis:** Das freigegebene GHCR-Image ist über das unveränderliche
  Versionstag öffentlich abrufbar und dem richtigen Repository zugeordnet.
- **Benötigter Nachweis:** Package-URL, Versionstag, Digest, Sichtbarkeit und
  Ergebnis eines anonymen Manifest-/Pull-Tests; keine Registry-Credentials.
- **Rollback:** Package wieder auf die vorherige Sichtbarkeit setzen und den
  Portainer-Cutover stoppen, falls falsche Artefakte oder Metadaten sichtbar
  wurden.
- **Freigabe für Folgetask:** MIG-011 erst nach Status `COMPLETED` oder nach
  dokumentierter Feststellung, dass keine Sichtbarkeitsänderung erforderlich
  war, beginnen.

## EXT-004: Portainer-Teststack erstellen

- **Status:** PENDING
- **Zugehöriger Task:** MIG-011
- **Verantwortlich:** Portainer-/Synology-Administrator
- **Warum extern:** Stack, Variablen, Volumes und Containerzustand liegen in der
  produktionsnahen Portainer- und Synology-Umgebung.
- **Voraussetzungen:** MIG-010 und EXT-008 sind abgeschlossen; das geprüfte
  GHCR-Image ist verfügbar; der Test verwendet getrennte Namen, Ports und
  persistente Pfade; benötigte Secrets sind lokal sicher bereitgestellt.
- **Exakte Schritte:** In Portainer einen eindeutig als Test gekennzeichneten
  Git-Stack mit Repository
  `https://github.com/tomas-fuerl/codeserver.git`, Reference `main` und
  Compose-Pfad `compose.yaml` anlegen. Alle Variablen gemäß
  `docs/CONFIGURATION.md` setzen, ein unveränderliches Versionstag verwenden
  und automatische GitOps-Updates deaktiviert lassen. Ausschließlich getrennte
  Testnamen, Loopback-Port und Testpfade verwenden. Stack starten und
  Containerstatus, Healthcheck, Login, Terminal, persistente Testdaten und Logs
  ohne Secret-Ausgabe prüfen.
- **Erwartetes Ergebnis:** Der isolierte Teststack ist healthy und erfüllt die
  technische sowie fachliche Testmatrix, ohne den Produktionsstack zu ändern.
- **Benötigter Nachweis:** Redigierter Stack-/Image-Bezug, Container- und
  Healthstatus, Prüfliste und Testergebnis.
- **Rollback:** Nur den Teststack stoppen und entfernen; Testdaten bis zur
  Fehleranalyse erhalten und erst nach separater Freigabe löschen.
- **Freigabe für Folgetask:** MIG-012 erst nach Status `COMPLETED`, erfolgreicher
  Testmatrix und bestätigter Rollbackfähigkeit beginnen.

## EXT-005: Produktiven Portainer-Stack umstellen

- **Status:** PENDING
- **Zugehöriger Task:** MIG-012
- **Verantwortlich:** Portainer-/Synology-Administrator
- **Warum extern:** Die Aktion ersetzt den produktiven Container und verändert
  den Portainer-Laufzeitstand.
- **Voraussetzungen:** EXT-004 ist abgeschlossen; aktuelles Backup und
  unabhängige Verifikation sind erfolgreich; Rollback-Stack und lokales Image
  `homelab-code-server:1.3.3` sind verfügbar; Wartungsfenster und Abnahme sind
  freigegeben.
- **Exakte Schritte:** Aktuelle Stackdefinition und Imagebezug redigiert
  sichern. Automatische GitOps-Updates deaktiviert bestätigen. Den produktiven
  Git-Stack auf Repository `https://github.com/tomas-fuerl/codeserver.git`,
  Reference `main` und Compose-Pfad `compose.yaml` umstellen. Alle finalen
  lokalen Variablen abgleichen und ein freigegebenes unveränderliches
  `CODESERVER_IMAGE_TAG` setzen. Container kontrolliert neu erstellen und
  danach Health, Loopback-Endpoint, Login, Terminal, Persistenz, Mounts, Logs
  und laufenden Image-Digest prüfen.
- **Erwartetes Ergebnis:** Der produktive Portainer-Stack läuft healthy mit dem
  freigegebenen GHCR-Image und unveränderten persistenten Nutzdaten.
- **Benötigter Nachweis:** Vorher-/Nachher-Stackreferenz, Image-Digest,
  Zeitfenster, Health- und fachliche Abnahme sowie Backup-Nachweis; alle Werte
  redigiert, die vertraulich sein könnten.
- **Rollback:** Gesicherte vorherige Stackdefinition mit
  `homelab-code-server:1.3.3` wiederherstellen, Container neu erstellen und die
  gleiche Abnahme durchführen. Persistente Daten nicht löschen.
- **Freigabe für Folgetask:** MIG-013 erst nach Status `COMPLETED` und erfolgreicher
  produktiver Erstabnahme beginnen.

## EXT-006: DSM-Aufgabenplaner auf neuen Skriptpfad umstellen

- **Status:** PENDING
- **Zugehöriger Task:** MIG-012
- **Verantwortlich:** Synology-Administrator
- **Warum extern:** Der DSM-Aufgabenplaner ist lokale Synology-Konfiguration und
  liegt außerhalb des Repositorys.
- **Voraussetzungen:** Der neue absolute Repository-/Skriptpfad ist final;
  Backup- und Verifikationsskripte wurden statisch geprüft; die Zuordnung von
  Config-, Secret-, Backup- und Containerwerten ist dokumentiert; bisheriger
  Zeitplan und Befehl sind redigiert gesichert.
- **Exakte Schritte:** Vorhandene Codeserver-Backupaufgabe in DSM öffnen,
  Benutzer, Zeitplan und Benachrichtigung unverändert kontrollieren. Den
  absoluten Skriptpfad auf `scripts/backup-config.sh` im neuen Repository
  umstellen und `CODESERVER_CONFIG_ROOT`, `CODESERVER_SECRET_ROOT`,
  `CODESERVER_BACKUP_ROOT` sowie `CODESERVER_CONTAINER_NAME` explizit mit den
  lokal geprüften Werten übergeben. Einen kontrollierten manuellen Lauf
  auslösen und dessen Exitstatus sowie die unabhängige Verifikation des neu
  erzeugten Backups dokumentieren.
- **Erwartetes Ergebnis:** Der bestehende Zeitplan ruft ausschließlich das neue
  Skript auf und ein Testlauf wird erfolgreich verifiziert.
- **Benötigter Nachweis:** Redigierter Aufgabenbefehl, Benutzer-/Zeitplanangabe,
  Laufzeitpunkt, Exitstatus und Verifikationsresultat ohne Backup- oder
  Secret-Inhalte.
- **Rollback:** Gesicherten bisherigen Skriptpfad wieder einsetzen und die neue
  Aufgabe deaktivieren, falls Test oder Verifikation fehlschlägt.
- **Freigabe für Folgetask:** MIG-013 benötigt Status `COMPLETED`; bei Fehler
  bleibt MIG-012 `BLOCKED`.

## EXT-007: Reverse Proxy und Firewall nach Cutover prüfen

- **Status:** PENDING
- **Zugehöriger Task:** MIG-013
- **Verantwortlich:** Synology-/Netzwerkadministrator
- **Warum extern:** DSM-Reverse-Proxy, Zertifikate, Router- und Firewallregeln
  sind aus dem Repository nicht verlässlich prüfbar.
- **Voraussetzungen:** EXT-005 und EXT-006 sind abgeschlossen; der produktive
  Stack ist healthy; bisherige Proxy- und Firewallkonfiguration ist gesichert;
  ein autorisiertes Testfenster ist vorhanden.
- **Exakte Schritte:** Bestätigen, dass das Ziel des
  DSM-HTTPS-Reverse-Proxys exakt
  `127.0.0.1:<CODESERVER_HOST_PORT>` ist; Zertifikat, WebSocket-Funktion und
  HSTS prüfen. Kontrollieren, dass nur die vorgesehenen externen Ports
  freigegeben sind, keine unerwünschte IPv6-Freigabe besteht und die
  DSM-Firewall die erforderlichen Regeln mit abschließender Deny-Regel
  enthält. Zugriff von den vorgesehenen Netzen und einen abgewiesenen Zugriff
  aus einem nicht erlaubten Pfad testen. Notwendige Änderungen einzeln
  dokumentieren und jeweils erneut prüfen.
- **Erwartetes Ergebnis:** Öffentlicher Zugriff funktioniert ausschließlich über
  den vorgesehenen HTTPS-/Reverse-Proxy-Pfad; direkte oder unerwünschte
  Freigaben sind nicht vorhanden.
- **Benötigter Nachweis:** Redigierte Prüfliste mit Zertifikats-, WebSocket-,
  Port-, IPv6- und Firewallergebnis sowie Zeitpunkt und verantwortlicher Person.
- **Rollback:** Bei einer fehlerhaften Änderung die gesicherte Proxy-/Firewall-
  Konfiguration wiederherstellen; bei unklarer Exposition externen Zugriff
  deaktivieren und MIG-013 blockieren.
- **Freigabe für Folgetask:** MIG-014 erst nach Status `COMPLETED` und vollständiger
  Backup-, Restore-, Laufzeit- und Netzwerkabnahme beginnen.


## EXT-008: Synology-Verzeichnisse und Secret-Datei prüfen

- **Status:** PENDING
- **Zugehöriger Task:** MIG-011; Voraussetzung für EXT-004
- **Verantwortlich:** Synology-/Portainer-Administrator
- **Warum extern:** Persistente Pfade, Eigentümer, Rechte und Secret-Metadaten
  existieren ausschließlich auf der lokalen Synology und dürfen in MIG-004
  weder gelesen noch verändert werden.
- **Voraussetzungen:** MIG-010 ist abgeschlossen; der finale Variablenvertrag
  wurde auf lokale Werte abgebildet; ein autorisiertes Wartungs- und
  Prüfzeitfenster ist vorhanden.
- **Exakte Schritte:** Prüfen, dass Config-, Secret-, Backup- und
  Restore-Testverzeichnis als absolute, voneinander getrennte Pfade existieren
  und keine Symlinks sind. Schreibrechte des Configpfads gegen die lokal
  ermittelten `PUID`/`PGID` abgleichen. Bestätigen, dass
  `<CODESERVER_SECRET_ROOT>/hashed_password` genau eine reguläre, nicht leere
  Datei mit Modus `0600` ist und Eigentümer sowie Gruppe dem lokalen
  Administrationsmodell entsprechen. Das Argon2-Format ausschließlich lokal
  mit einem geeigneten Werkzeug validieren, ohne Inhalt, Hash oder
  Zugangsdaten auszugeben.
- **Erwartetes Ergebnis:** Alle vier Verzeichnisrollen sind eindeutig getrennt;
  der Configpfad ist für den Containerbenutzer geeignet; die Secret-Datei
  erfüllt Dateityp-, Nicht-Leere-, Format-, Eigentümer- und Modusvertrag.
- **Benötigter Nachweis:** Redigierte Zuordnung der vier Pfadrollen,
  UID-/GID-Abgleich, boolesche Ergebnisse zu Verzeichnis-/Symlinkprüfung sowie
  Secret-Dateiname, Dateityp, Nicht-Leere, Modus und Eigentümerklasse. Keine
  Pfadinhalte, Secret-Inhalte oder Passwort-Hashes in den Nachweis übernehmen.
- **Rollback / sichere Abbruchbedingung:** Die Prüfung selbst verändert nichts.
  Bei Abweichung weder Test- noch Produktivstack deployen. Korrekturen nur nach
  separater lokaler Freigabe durchführen; keine persistente Datei und kein
  Verzeichnis löschen. Bei unklarer Secret-Herkunft die Datei nicht verwenden
  und MIG-011 blockieren.
- **Freigabe für Folgeschritt:** EXT-004 erst nach Status `COMPLETED` und
  vollständig dokumentiertem redigiertem Nachweis beginnen.

## EXT-009: Zielarchitektur vor dem ersten Release bestätigen

- **Status:** PENDING
- **Zugehöriger Task:** MIG-006 oder MIG-010; spätestens vor dem ersten Release
- **Verantwortlich:** Repository-Eigentümer und Synology-/Portainer-Administrator
- **Warum extern:** Die tatsächliche Zielarchitektur und eine mögliche
  Laufzeitfreigabe lassen sich aus dem lokalen history-freien Arbeitsbaum nicht
  abschließend bestätigen.
- **Voraussetzungen:** MIG-005 ist menschlich abgenommen; die vorgesehene
  Zielhardware und der spätere Testpfad sind bekannt.
- **Exakte Schritte:** `linux/amd64` als erwarteten Startwert gegen die
  Zielhardware bestätigen. `linux/arm64` nur dann in den Workflowvertrag
  aufnehmen, wenn ein separater Build erfolgreich ist und das resultierende
  Image auf einer autorisierten ARM64-Zielumgebung die vollständige
  Laufzeitabnahme besteht. Keine Architekturannahme ohne Nachweis als bestätigt
  markieren.
- **Erwartetes Ergebnis:** Die erste Releaseplattform ist dokumentiert und
  nachgewiesen. Ohne abweichenden Nachweis bleibt der Workflow auf
  `linux/amd64` begrenzt.
- **Benötigter Nachweis:** Redigierte Hardware-/Plattformangabe, Buildresultat
  und bei ARM64 zusätzlich Runtime-, Health- und Funktionsabnahme; keine
  Zugangsdaten oder lokalen Secretwerte.
- **Rollback / sichere Abbruchbedingung:** Bei unklarer oder abweichender
  Architektur keinen Release auslösen. Plattformmatrix erst in einem separat
  reviewten Änderungsscope erweitern.
- **Freigabe für Folgeschritt:** MIG-010 darf das erste Image nur für eine
  bestätigte Plattform veröffentlichen.

## EXT-011: Spezialisierten Secret-Scan ausführen

- **Status:** NOT_REQUIRED
- **Zugehöriger Task:** MIG-006
- **Verantwortlich:** Codex im genehmigten Container-Scope
- **Begründung:** Die Prüfung wird im genehmigten Container-Scope mit einem
  offiziell veröffentlichten und SHA-256-verifizierten Gitleaks-Release
  ausgeführt. Keine Betreiberaktion außerhalb des Containers ist erforderlich.
- **Nachweis:** Gitleaks v8.30.1, Manifest- und Archivprüfsumme, redigierter
  Scanstatus und vollständige Bereinigung werden in MIG-006 dokumentiert.

## EXT-010: Lokalen Docker-Build und Toolchain-Smoke-Test ausführen

- **Status:** COMPLETED
- **Zugehöriger Task:** MIG-006
- **Verantwortlich:** Betreiber
- **Review:** Durch menschliches Review genehmigt.
- **Testimage:** `codeserver:mig006-local`
- **Gesamtergebnis:** PASS

### Maßgeblicher Betreiberbeleg

| Prüfung | Ergebnis |
| --- | --- |
| Docker-Build | Exit-Code 0 |
| Image-Inspect | Exit-Code 0 |
| Architektur | `amd64` |
| Betriebssystem | `linux` |
| code-server | `4.128.0` |
| code-server Commit | `cb22f74650a539d6f824d5944ec34d9e74844f66` |
| Code-Version | `1.128.0` |
| Node | `v24.18.0` |
| pnpm | `10.13.1` |
| PowerShell | `7.6.3` |
| Codex | `codex-cli 0.144.5` |
| Toolchain-Smoke-Test | Exit-Code 0 |
| Image-Entfernung | Exit-Code 0 |
| Testimage entfernt | ja |
| Containerbestand unverändert | ja |

Der erste Testlauf scheiterte ausschließlich daran, dass für code-server ein
falscher Binary-Pfad aufgerufen wurde. Der korrigierte und erfolgreiche finale
Lauf verwendete `/app/code-server/bin/code-server`. Dieser finale Lauf ersetzt
den fehlgeschlagenen Zwischenlauf als maßgeblichen EXT-010-Nachweis. Der
Image-Build selbst und die Toolchain waren dadurch nicht widerlegt.

### Sicherheits- und Cleanup-Nachweis

- keine Ports veröffentlicht;
- keine Mounts verwendet;
- keine Secrets verwendet;
- kein Image gepusht;
- kein Dienst gestartet;
- Testimage nach dem Smoke-Test entfernt;
- keine produktiven Container verändert;
- Containerbestand vor und nach dem Test unverändert;
- keine privaten Hostpfade in den öffentlichen Nachweis übernommen.

EXT-010 ist vollständig erfüllt und blockiert MIG-006 nicht mehr.

## EXT-012: Offizielle GitHub-CLI- und Basisimageinformationen abrufen

- **Status:** COMPLETED
- **Zugehöriger Task:** MIG-016
- **Verantwortlich:** Codex nach ausdrücklicher Netzwerkfreigabe
- **Warum extern:** Aktuelle stabile Version, offizielle Prüfsummenliste und
  öffentliche Basisimageinformationen liegen außerhalb des Repositorys.
- **Voraussetzungen:** Strikt lesender Zugriff ausschließlich auf offizielle
  GitHub-CLI- und LinuxServer-Quellen, ohne Authentifizierung oder Tokens.
- **Exakte Schritte:** Aktuelles stabiles Release, `linux_amd64`- und
  `linux_arm64`-Archive und deren Einträge in der offiziellen
  SHA-256-Prüfsummenliste abgleichen. Öffentliche LinuxServer-Informationen auf
  HOME-/`/config`-Verhalten prüfen.
- **Erwartetes Ergebnis:** Exakte Version, Quellen, Architekturzuordnung und
  belegbare Persistenzbewertung liegen ohne private Daten vor.
- **Benötigter Nachweis:** Öffentliche URLs, Version, Archivnamen,
  Prüfsummenabgleich und redigierter Basisimagebefund; keine Credentials.
- **Rollback / sichere Abbruchbedingung:** Bei Unklarheit keine Werte oder
  Pfade raten und MIG-016 bis zur Klärung blockieren.

### Nachweis

- Die offizielle Latest-Release-API meldete am 2026-07-23 `v2.96.0` als
  veröffentlichtes, unveränderliches, nicht als Prerelease markiertes Release.
- Offizielle Releasequelle:
  `https://github.com/cli/cli/releases/tag/v2.96.0`.
- Offizielle Prüfsummenliste:
  `https://github.com/cli/cli/releases/download/v2.96.0/gh_2.96.0_checksums.txt`.
  Ihr von GitHub veröffentlichter Asset-Digest
  `fc046371efa250e2875208341a786a35a01717d5eebec6903e199a9b8a3f3565`
  wurde erfolgreich geprüft.
- `linux_amd64`-Archivchecksumme:
  `83d5c2ccad5498f58bf6368acb1ab32588cf43ab3a4b1c301bf36328b1c8bd60`.
- `linux_arm64`-Archivchecksumme:
  `06f86ec7103d41993b76cd78072f43595c34aaa56506d971d9860e67140bf909`.
- Die offizielle LinuxServer-Dockerfile-Definition setzt `HOME=/config`; die
  Basisdefinition setzt kein `XDG_CONFIG_HOME`. Die offizielle `gh`-Dokumentation
  verwendet ohne Override `$HOME/.config/gh`. Daraus folgt für diesen
  Imagevertrag der persistente Standardpfad `/config/.config/gh`.

## EXT-013: MIG-016-Runtime und GitHub-CLI-Persistenz prüfen

- **Status:** COMPLETED
- **Zugehöriger Task:** MIG-016
- **Verantwortlich:** Betreiber
- **Warum extern:** GitHub Actions hat das Image gebaut, aber keinen Container
  gestartet oder geladen. Codex darf nicht auf Docker-Daemon oder
  Docker-Socket zugreifen und führt keine interaktive GitHub-Anmeldung aus.
- **Voraussetzungen:** Lokale MIG-016-Gates und der GitHub-Actions-Build sind
  erfolgreich; das unveränderliche veröffentlichte Releaseimage und ein
  isolierter persistenter Test-`/config`-Mount stehen ohne Produktionsdaten
  bereit.
- **Exakte Schritte:** Einen echten Testcontainer ohne veröffentlichte Ports,
  Produktionsmounts oder Credentials starten. Darin ausschließlich vorhandene
  Imagewerkzeuge prüfen: `command -v gh`, `gh --version`, `node --version`,
  `pnpm --version`, `pwsh --version`, `codex --version`,
  `printf 'HOME=%s\n' "$HOME"`,
  `printf 'XDG_CONFIG_HOME=%s\n' "${XDG_CONFIG_HOME:-}"`,
  `printf 'GH_CONFIG_DIR=%s\n' "${GH_CONFIG_DIR:-}"` und
  `printf 'GH_TELEMETRY=%s\n' "${GH_TELEMETRY:-}"` ausführen. HOME und den
  daraus resultierenden GitHub-CLI-Konfigurationspfad bewerten. Die
  Repositoryskripte `scripts/verify-developer-tools.sh` und
  `scripts/verify-toolchain.sh` werden nicht im Container aufgerufen; das
  Dockerfile übernimmt keine Repositorydateien per `COPY` oder `ADD`.
  Anschließend die interaktive Anmeldung als getrennten späteren
  Betreiberschritt ausführen, ohne Credentials oder `hosts.yml`-Inhalte
  auszugeben. Den Testcontainer mit demselben `/config`-Mount neu starten und
  mit `gh auth status` bestätigen, dass die Anmeldung persistiert.
- **Erwartetes Ergebnis:** Die installierten Imagewerkzeuge laufen in einem
  echten Container mit den erwarteten Versionen; `HOME=/config`, der
  Konfigurationspfad ist eindeutig persistent, `GH_TELEMETRY=false` und die
  spätere Anmeldung übersteht einen Containerneustart.
- **Benötigter Nachweis:** Containerstart und Neustart, Architektur,
  Werkzeugversionen, HOME, leere oder explizite XDG-/`GH_CONFIG_DIR`-Werte,
  `GH_TELEMETRY=false`, klassifizierter Konfigurationspfad und erfolgreicher
  `gh auth status` nach dem Neustart; keine Tokens oder Inhalte von `hosts.yml`.
- **Rollback / sichere Abbruchbedingung:** Bei Fehler kein Deployment und keine
  Anmeldung. Produktive Container und persistente Daten unverändert lassen.

### CI- und Veröffentlichungsnachweis

GitHub Actions führte für Commit
`8d1088f4f53ec25bc4ffe82deeba0edc95f52dd2` den Workflow `CI`, Lauf 5
(`30039001584`), erfolgreich aus. Im Job `validate-and-build` bestanden
`Validate repository`, `Validate Compose contract` und
`Build image without publishing` für `linux/amd64`. Der Build verwendete
`push: false` und `load: false`; ein Container wurde deshalb weder gestartet
noch auf Persistenz geprüft.

Der erfolgreiche Workflow `Publish container image`, Lauf `30041049040`,
veröffentlichte anschließend für Tag `v1.5.0` und Commit
`ca82b17bf9049b202244c1c8765c86217b39aead` das `linux/amd64`-Image
`ghcr.io/tomas-fuerl/codeserver:1.5.0` mit Digest
`sha256:9f1db9f29b10b1eea956d1803fcade35c7bf75ef476ea43a03c1abddeddeb82b`.

### Maßgeblicher Betreiberbeleg

Der Betreiber meldete EXT-013 am 2026-07-23 ausdrücklich als erfolgreich
abgeschlossen. Die getesteten Platzhalter wurden gegen den erfolgreichen
öffentlichen Publish-Lauf eindeutig auf Version `1.5.0` und den oben genannten
Digest aufgelöst.

| Prüfung | Ergebnis |
| --- | --- |
| Releaseimage veröffentlicht | ja |
| Getestete Imageversion | `1.5.0` |
| Getesteter Image-Digest | `sha256:9f1db9f29b10b1eea956d1803fcade35c7bf75ef476ea43a03c1abddeddeb82b` |
| Plattform | `linux/amd64` |
| Isolierter Testcontainer gestartet | ja |
| Containerstatus | `running` |
| Healthstatus | `healthy` |
| GitHub CLI | `gh version 2.96.0` |
| `HOME` | `/config` |
| `XDG_CONFIG_HOME` | leer |
| `GH_CONFIG_DIR` | leer |
| `GH_TELEMETRY` | `false` |
| `/config`-Persistenz über Neustart | bestätigt |
| Bestehender code-server aktualisiert | ja, auf die geprüfte Version |
| `gh auth login` im dauerhaften code-server | durch den Betreiber ausgeführt |
| `gh auth status` nach Neustart | erfolgreich |
| Authentifizierter Benutzer | `tomas-fuerl` |
| Tokens oder Inhalte von `hosts.yml` protokolliert | nein |

Codex hat weder Docker-Daemon noch Docker-Socket verwendet, keine
Authentifizierungsdatei geöffnet und weder Anmeldung noch Update oder
Deployment ausgeführt. Der Betreiberbeleg enthält keine Tokens oder
`hosts.yml`-Inhalte. Damit sind Runtime-, Health-, Konfigurationspfad-,
Neustart- und Anmeldepersistenzprüfung erfüllt; EXT-013 blockiert MIG-016 nicht
mehr.
