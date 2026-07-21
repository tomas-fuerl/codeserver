# Backup und Restore-Test

Die Betriebsskripte sind für spätere kontrollierte Aufrufe auf dem
Synology-Host vorgesehen. Sie besitzen keine produktiven Pfaddefaults, lesen
keine Environment-Datei und werden in MIG-004 nicht ausgeführt.

## Sicherungsumfang und Format

`scripts/backup-config.sh` sichert:

- den persistenten code-server-Konfigurationsbaum einschließlich `workspace/`,
  `data/` und `.codex/`;
- die externe Passwort-Hashdatei unter dem kanonischen Archivpfad
  `secrets/hashed_password`.

Rekonstruierbare oder flüchtige Inhalte wie `node_modules`, `.codex/tmp`,
`.cache`, `.npm` und `.pnpm-store` bleiben ausgeschlossen. Das Skript erzeugt
ein zeitgestempeltes `.tar.gz`-Archiv, eine SHA-256-Sidecardatei und ein
Manifest. Anschließend muss `scripts/verify-backup.sh` das neue Archiv
erfolgreich prüfen.

Archive können vertrauliche Workspace-, Repository-, SSH-,
Anwendungs- und Secret-Daten enthalten. Archiv, Prüfsumme, Manifest und externe
Kopien werden restriktiv gespeichert. Secret-Inhalte werden weder
protokolliert noch in das Manifest übernommen.

## Expliziter Backupvertrag

Vor einem späteren Aufruf setzt der Betreiber ausschließlich:

| Variable | Bedeutung |
| --- | --- |
| `CODESERVER_CONFIG_ROOT` | Absoluter Pfad aus `CODESERVER_CONFIG_PATH` |
| `CODESERVER_SECRET_ROOT` | Elternverzeichnis aus `CODESERVER_SECRET_FILE` |
| `CODESERVER_BACKUP_ROOT` | Absoluter Pfad aus `CODESERVER_BACKUP_PATH` |
| `CODESERVER_CONTAINER_NAME` | Containername aus dem Portainer-Vertrag |

Fehlende Werte, `CHANGE_ME`, relative Pfade, gleiche Pfade oder ein Backupziel
innerhalb des Configbaums führen vor Datei- oder Dockeroperationen zum
Abbruch. Die erwartete Secretquelle wird ausschließlich als
`<CODESERVER_SECRET_ROOT>/hashed_password` abgeleitet.

Ein zukünftiger Aufruf ist eine `EXTERNAL OPERATOR ACTION`:

```bash
sudo env \
  CODESERVER_CONFIG_ROOT="<CODESERVER_CONFIG_PATH>" \
  CODESERVER_SECRET_ROOT="<CODESERVER_SECRET_ROOT>" \
  CODESERVER_BACKUP_ROOT="<CODESERVER_BACKUP_PATH>" \
  CODESERVER_CONTAINER_NAME="<CODESERVER_CONTAINER_NAME>" \
  "<REPOSITORY_ROOT>/scripts/backup-config.sh"
```

Falls der Container läuft, erstellt das Skript zunächst eine Arbeitskopie,
stoppt ihn für den finalen Abgleich kontrolliert höchstens 30 Sekunden und
startet ihn sofort wieder. MIG-004 führt diesen Ablauf nicht aus.

## Unabhängige Integritätsprüfung

`scripts/verify-backup.sh` prüft:

- SHA-256-Prüfsumme und Lesbarkeit des Tar-Archivs;
- sichere, nicht ausbrechende Archivpfade;
- die Pflichtverzeichnisse `workspace/`, `data/` und `.codex/`;
- genau eine nicht leere Secret-Datei unter
  `secrets/hashed_password` mit Modus `0600`.

Die Prüfung verändert keine Backupdatei und gibt den Secret-Inhalt nicht aus.

## Expliziter Restore-Testvertrag

`scripts/restore-config.sh` verwendet ausschließlich:

| Variable | Bedeutung |
| --- | --- |
| `CODESERVER_CONFIG_ROOT` | Produktiver Configpfad, der niemals Restoreziel sein darf |
| `CODESERVER_SECRET_ROOT` | Produktiver Secretpfad, der niemals Restoreziel sein darf |
| `CODESERVER_RESTORE_ROOT` | Absolute Basis für nicht-destruktive Restore-Testziele |
| `CODESERVER_CONTAINER_NAME` | Containername zur Ermittlung des lokal vorhandenen Hilfsimages |

Zusätzlich werden ein absolutes Archiv und ein absolutes Ziel über
`--archive` und `--target` angegeben. Das Ziel muss strikt unter
`CODESERVER_RESTORE_ROOT` liegen. Ein vorhandenes nicht leeres Ziel sowie
Config-, Secret- oder Restore-Root selbst werden abgelehnt.

Ein zukünftiger Aufruf ist eine `EXTERNAL OPERATOR ACTION`:

```bash
sudo env \
  CODESERVER_CONFIG_ROOT="<CODESERVER_CONFIG_PATH>" \
  CODESERVER_SECRET_ROOT="<CODESERVER_SECRET_ROOT>" \
  CODESERVER_RESTORE_ROOT="<CODESERVER_RESTORE_PATH>" \
  CODESERVER_CONTAINER_NAME="<CODESERVER_CONTAINER_NAME>" \
  "<REPOSITORY_ROOT>/scripts/restore-config.sh" \
  --archive "<ABSOLUTE_BACKUP_ARCHIVE>" \
  --target "<CODESERVER_RESTORE_PATH>/<EMPTY_TEST_NAME>"
```

Vor der Extraktion laufen Integritäts- und Pfadprüfungen. Danach werden
Pflichtverzeichnisse, Secret-Dateityp, Nicht-Leere und Modus erneut geprüft.
Gefundene Git-Repositories werden im lokal vorhandenen Containerimage über ein
read-only Mount validiert. Produktive Daten werden nicht überschrieben.

## Späterer Notfall-Restore

Ein produktiver Restore bleibt absichtlich manuell:

1. Ursache klären und weitere Schreibzugriffe begrenzen.
2. Ein geeignetes Archiv unabhängig verifizieren.
3. In ein neues leeres Testziel restaurieren.
4. Inhalte, Rechte, Eigentümerabbildung, Repositories und Secret-Metadaten
   prüfen, ohne Secret-Inhalte auszugeben.
5. Den aktuellen produktiven Zustand als getrennte Rückfallebene sichern.
6. Den geprüften Datenbestand erst nach ausdrücklicher Freigabe übertragen.
7. Dienst, Logs, Login und Persistenz prüfen; bei Fehlern auf die
   Rückfallebene zurückgehen.

Das Restore-Testskript selbst überschreibt keine produktiven Daten.

## DSM-Aufgabenplanung

Eine spätere DSM-Aufgabe ruft das Backupskript über einen absoluten
Repositorypfad und mit den vier expliziten Variablen auf. Benutzer, Zeitplan,
Benachrichtigung, lokale Pfade und der konkrete Befehl bleiben lokale
Betreiberkonfiguration. Die Umstellung und ein kontrollierter Testlauf gehören
zu `EXT-006`; sie werden in MIG-004 nicht ausgeführt.
