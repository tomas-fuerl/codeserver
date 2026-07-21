# Entscheidungsprotokoll

Dieses Dokument hält verbindliche Architektur- und Migrationsentscheidungen
für die Codeserver-Auslagerung fest. Änderungen benötigen eine neue oder
ausdrücklich revidierende Entscheidung; frühere Entscheidungen werden nicht
stillschweigend überschrieben.

## DEC-001: Homelab bleibt privat

- **Status:** ACCEPTED
- **Kontext:** Der aktuelle Baum und die erreichbare Historie enthalten lokale
  Environment-Artefakte und private Betriebsinformationen.
- **Entscheidung:** Das bestehende Repository `tomas-fuerl/Homelab` bleibt
  privat.
- **Begründung:** Eine direkte Veröffentlichung würde eine Historienbereinigung,
  eine wertbezogene Secret-Prüfung und weitere externe Prüfungen voraussetzen.
- **Konsequenzen:** Codeserver wird über einen sanitisierten, eigenständigen
  Arbeitsbaum migriert; die Sichtbarkeit von Homelab wird nicht geändert.
- **Mögliche spätere Neubewertung:** Nur in einem separaten Security-Projekt mit
  vollständiger Historien-, Secret- und GitHub-Datenprüfung.

## DEC-002: Name des Ziel-Repositorys

- **Status:** ACCEPTED
- **Kontext:** Für den öffentlich gepflegten Codeserver wird eine eindeutige
  Zieladresse benötigt.
- **Entscheidung:** Das neue Repository heißt `tomas-fuerl/codeserver`.
- **Begründung:** Der Name entspricht dem Produkt und entkoppelt es vom
  Homelab-Monorepository.
- **Konsequenzen:** Dokumentation, Workflows, Image-Metadaten und Clone-Beispiele
  werden auf diesen Namen ausgerichtet.
- **Mögliche spätere Neubewertung:** Nur vor der ersten Veröffentlichung; danach
  würde eine Umbenennung zusätzliche Redirect-, Package- und Deploymentarbeit
  verursachen.

## DEC-003: Neue Git-Historie

- **Status:** ACCEPTED
- **Kontext:** Environment-Dateien sind in der erreichbaren alten Historie
  vorhanden; ein sanitiserter Snapshot wurde als grundsätzlich
  veröffentlichungsfähig bewertet.
- **Entscheidung:** Das neue Repository erhält eine neue Git-Historie ohne
  Objekte, Refs oder Metadaten der Homelab-Historie.
- **Begründung:** Eine History-Free-Migration begrenzt das Risiko, alte Secrets
  oder private Betriebsdetails zu veröffentlichen.
- **Konsequenzen:** Kein Fork, kein Subtree mit alter Historie und kein
  Repository-Filterexport; der Initial-Commit entsteht erst nach Audit und
  Freigabe.
- **Mögliche spätere Neubewertung:** Keine Übernahme der alten Historie nach der
  Veröffentlichung; historische Herkunft kann nur redaktionell dokumentiert
  werden.

## DEC-004: Genau ein Codeserver-Repository

- **Status:** ACCEPTED
- **Kontext:** Doppelpflege würde Quellstand, Dokumentation und Releaseprozess
  auseinanderlaufen lassen.
- **Entscheidung:** Nach Abschluss der Migration wird ausschließlich
  `tomas-fuerl/codeserver` als Codeserver-Repository gepflegt.
- **Begründung:** Eine einzige Source of Truth vereinfacht Reviews, Releases und
  den Portainer-Vertrag.
- **Konsequenzen:** Der Codeserver-Bereich wird erst nach erfolgreichem Cutover
  und Abnahme in MIG-014 aus Homelab entfernt; bis dahin ist er Rollbackquelle.
- **Mögliche spätere Neubewertung:** Nur bei einer klar abgegrenzten, unabhängig
  versionierten Komponente.

## DEC-005: Produktive Konfiguration bleibt außerhalb von Git

- **Status:** ACCEPTED
- **Kontext:** Produktive Environment- und Secret-Dateien enthalten lokale oder
  vertrauliche Werte.
- **Entscheidung:** Produktive `.env`, `stack.env`, Passwort-Hashes und Secrets
  bleiben außerhalb jedes Git-Repositorys.
- **Begründung:** Platzhalter und ein dokumentierter Konfigurationsvertrag
  reichen für Reproduzierbarkeit aus, ohne Credentials offenzulegen.
- **Konsequenzen:** Das öffentliche Repository enthält nur `.env.example` und
  Variablennamen; reale Werte werden in Synology beziehungsweise Portainer
  verwaltet und separat gesichert.
- **Mögliche spätere Neubewertung:** Ein dediziertes Secret-Management-System
  kann die lokale Ablage ersetzen, aber Secrets bleiben unversioniert.

## DEC-006: Portainer als produktiver Deploymentmechanismus

- **Status:** ACCEPTED
- **Kontext:** Der Zielbetrieb soll über einen klaren Compose-Vertrag auf der
  Synology verwaltet werden.
- **Entscheidung:** Portainer ist der produktive Deploymentmechanismus.
- **Begründung:** Stackdefinition, Variablen und kontrollierter Cutover lassen
  sich dort konsistent verwalten und prüfen.
- **Konsequenzen:** `compose.yaml` wird für Portainer entworfen; direkte lokale
  Deploymentskripte werden ersetzt oder auf reine Prüf-/Hilfsfunktionen
  reduziert.
- **Mögliche spätere Neubewertung:** Nach stabiler Produktion kann ein anderes
  Orchestrierungsmodell als eigener Migrationstask bewertet werden.

## DEC-007: Image-Build ausschließlich über GitHub Actions

- **Status:** ACCEPTED
- **Kontext:** Lokale Produktionsbuilds koppeln die Synology an Buildwerkzeuge
  und erschweren die Provenienz.
- **Entscheidung:** GitHub Actions baut das veröffentlichte Image; die Synology
  baut kein Produktivimage mehr.
- **Begründung:** Ein zentraler, reviewbarer Workflow liefert reproduzierbare
  Builds und Registry-Artefakte.
- **Konsequenzen:** Portainer zieht ein geprüftes GHCR-Image; Build- und
  Publish-Berechtigungen liegen ausschließlich im CI-Workflow.
- **Mögliche spätere Neubewertung:** Nur bei einem dokumentierten CI-Ausfallplan;
  ein lokaler Notfallbuild darf nicht stillschweigend zum Standard werden.

## DEC-008: GHCR mit unveränderlichen Versionstags

- **Status:** ACCEPTED
- **Kontext:** Deployment und Rollback benötigen eindeutig referenzierbare
  Artefakte.
- **Entscheidung:** Images werden über GHCR mit unveränderlichen Versionstags
  veröffentlicht.
- **Begründung:** Ein Tag muss dauerhaft genau demselben Image-Inhalt entsprechen
  und dadurch überprüfbare Rollbacks erlauben.
- **Konsequenzen:** Vorhandene Tags werden nie überschrieben; der Workflow muss
  Tagformat, Zielrepository und veröffentlichte Metadaten prüfen. Ein
  Digest-Pinning bleibt zusätzlich möglich.
- **Mögliche spätere Neubewertung:** Zusätzliche bewegliche Komfort-Tags dürfen
  nur ergänzt werden, wenn Deployments weiterhin Version oder Digest pinnen.

## DEC-009: Keine automatischen GitOps-Updates beim ersten Cutover

- **Status:** ACCEPTED
- **Kontext:** Der erste produktive Wechsel benötigt kontrollierte Prüf- und
  Rollbackpunkte.
- **Entscheidung:** Automatische Portainer-GitOps-Updates bleiben beim ersten
  Cutover deaktiviert.
- **Begründung:** Ein manueller, nachweisbarer Versionswechsel reduziert das
  Risiko einer ungeprüften Container-Neuerstellung.
- **Konsequenzen:** Stackänderungen werden explizit geprüft und ausgelöst; erst
  nach stabiler Laufzeit darf Automatisierung bewertet werden.
- **Mögliche spätere Neubewertung:** Nach MIG-015 mit definierten Gates,
  Benachrichtigung, Healthchecks und getestetem Rollback.

## DEC-010: Lokales Image als Rollbackbasis erhalten

- **Status:** ACCEPTED
- **Kontext:** Der bestehende produktive Stand benötigt während der Migration
  eine unabhängig von GitHub und GHCR verfügbare Rückfallebene.
- **Entscheidung:** Das bisherige lokale Image
  `homelab-code-server:1.3.3` bleibt bis nach der vollständigen Migration
  erhalten.
- **Begründung:** Damit kann der vorherige Stack wiederhergestellt werden, falls
  der neue Image-, Registry- oder Portainerpfad fehlschlägt.
- **Konsequenzen:** MIG-011 bis MIG-013 dürfen das Image nicht löschen oder
  überschreiben; eine Bereinigung ist frühestens nach MIG-015 separat zulässig.
- **Mögliche spätere Neubewertung:** Nach vollständiger Backup-, Restore-,
  Laufzeit- und Rollbackabnahme sowie dokumentierter Betreiberfreigabe.
