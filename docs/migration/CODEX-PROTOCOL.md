# Codex-Protokoll für die Codeserver-Migration

## Zweck

Dieses Protokoll steuert die Migration aus dem privaten Repository `Homelab`
in das eigenständige öffentliche Repository `tomas-fuerl/codeserver`. Es gilt
für alle in `MIGRATION-PLAN.md` geführten Aufgaben. Task-spezifische Vorgaben
können den Scope weiter einschränken, aber nicht stillschweigend erweitern.

## Verbindlicher Arbeitszyklus

1. Es wird immer genau ein `MIG`-Task gleichzeitig bearbeitet.
2. Vor Beginn werden Taskstatus, Abhängigkeiten, erlaubte Dateien und die für
   den Task relevanten Einträge in `EXTERNAL-ACTIONS.md` geprüft.
3. Ein Task darf nur begonnen werden, wenn seine Abhängigkeiten erfüllt sind.
   Eine für ihn notwendige externe Aktion mit `PENDING`, `FAILED` oder
   `BLOCKED` sperrt ihn ab dem Zeitpunkt, an dem der Task erreicht wird.
4. Vor Änderungen werden Branch und Arbeitsbaum geprüft. Bestehende
   uncommittete Änderungen werden weder überschrieben noch zurückgesetzt.
5. Ziel, Annahmen und betroffene Dateien werden vor der ersten Änderung kurz
   benannt. Änderungen bleiben klein, nachvollziehbar und reviewbar.
6. Es werden ausschließlich die im aktiven Task erlaubten Dateien und Aktionen
   bearbeitet. Eine Scope-Erweiterung benötigt einen neuen oder ausdrücklich
   erweiterten Task.
7. Nach den Änderungen werden alle im Task verlangten Prüfungen ausgeführt.
   Nicht ausführbare Prüfungen werden mit Ursache und Risiko dokumentiert und
   niemals als erfolgreich angenommen.
8. `MIGRATION-PLAN.md`, gegebenenfalls `DECISIONS.md` und das Dokument des
   aktiven Tasks werden auf den tatsächlich erreichten Stand gebracht.
9. Jeder Task endet mit einem lokalen `TASK-RESULT.md`, das Änderungen,
   Prüfungen, offene Risiken, externe Aktionen und den eindeutigen Status nennt.
10. Ein Commit wird nur nach ausdrücklicher Erlaubnis und nur in einem dafür
    vorgesehenen Task erstellt.

## Externe Aktionen

Eine externe Aktion ist jede notwendige Änderung außerhalb des verfügbaren
Containers und Repository-Arbeitsbaums, insbesondere an GitHub, GHCR,
Portainer, Synology DSM, Reverse Proxy, Firewall, produktiven Containern oder
Secrets.

Codex führt keine nicht ausdrücklich genehmigte externe Aktion aus. Sobald eine
solche Aktion notwendig wird:

1. wird die Bearbeitung an einem sicheren Zwischenstand gestoppt;
2. wird kein Erfolg simuliert, geschätzt oder vorausgesetzt;
3. wird ein Eintrag mit eindeutiger `EXT-XXX`-ID in
   `EXTERNAL-ACTIONS.md` angelegt oder aktualisiert;
4. wird der zugehörige `MIG`-Task auf `BLOCKED` gesetzt;
5. nennt `TASK-RESULT.md` die ausstehende Aktion, den benötigten Nachweis und
   die Bedingung für die Fortsetzung;
6. wird erst nach dokumentiertem Nachweis und Status `COMPLETED` fortgesetzt.

Geplante `PENDING`-Aktionen für spätere Tasks blockieren den aktuellen Task
nicht. Sie werden erst dann zu einem Gate, wenn der zugehörige Task erreicht
wird.

## Sicherheit und Vertraulichkeit

- Passwörter, Tokens, API-Schlüssel, Passwort-Hashes und andere Secret-Werte
  werden weder gelesen noch ausgegeben oder in Berichte übernommen.
- Inhalte produktiver `.env`-, `stack.env`-, Authentifizierungs- und
  Secret-Dateien werden nicht geöffnet.
- Remote-URLs werden vor der Dokumentation auf eingebettete Credentials
  geprüft und gegebenenfalls redigiert.
- Produktive Environment-Dateien, Backups, Restore-Testdaten, Logs und lokale
  Portainer-, DSM-, Reverse-Proxy- oder Firewall-Konfigurationen werden nie in
  Git übernommen.
- Alte Homelab-Git-Historie wird nicht in das öffentliche Repository kopiert.
- Docker-Daemon, Docker-Socket und produktive Systeme werden nur in einem
  ausdrücklich dafür freigegebenen späteren Task verwendet.

## Git-Regeln

- Nicht direkt auf `main` arbeiten, sofern ein Task dies nicht ausdrücklich
  verlangt.
- Keine Branches wechseln oder erstellen, keine Tags setzen und keine Historie
  umschreiben, sofern dies nicht zum aktiven Task gehört und ausdrücklich
  freigegeben ist.
- Kein Force-Push.
- Kein Push, Fetch oder anderer Netzwerkzugriff ohne die erforderliche
  Freigabe und ein passendes External-Action-Gate.
- Keine vorhandenen Benutzeränderungen verwerfen.
- Ein Taskstatus darf nicht durch einen Commit oder Remote-Erfolg vorweggenommen
  werden.

## Statusführung

Migrationstasks verwenden ausschließlich:

```text
NOT_STARTED
IN_PROGRESS
BLOCKED
READY_FOR_REVIEW
COMPLETED
FAILED
```

Externe Aktionen verwenden ausschließlich:

```text
NOT_REQUIRED
PENDING
COMPLETED
FAILED
BLOCKED
```

`READY_FOR_REVIEW` bedeutet, dass der vereinbarte Scope umgesetzt und lokal
geprüft wurde, aber noch eine menschliche Abnahme aussteht. `COMPLETED` wird
erst nach dieser Abnahme verwendet. Bei einer Blockade wird sicher gestoppt;
der Status bleibt nicht irreführend `IN_PROGRESS`.

## Abschlussnachweis

Der Abschlussbericht enthält mindestens:

- aktiven Task und finalen Status;
- Ausgangszustand und geänderte Dateien;
- ausgeführte Prüfungen mit Ergebnis;
- nicht geprüfte Annahmen und verbleibende Risiken;
- externe Aktionen mit Status und Nachweisen;
- Bestätigung zu Scope, Secrets, Git-Historie, Remote und Commit;
- den vorgeschlagenen nächsten Task, ohne diesen zu beginnen.
