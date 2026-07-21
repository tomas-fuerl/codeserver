# Kontrollierte Updates und Rollbacks

Portainer ist der produktive Deploymentmechanismus. Updates und Rollbacks
verwenden ausschließlich explizite, freigegebene GHCR-Versionstags. Dieser
Stand dokumentiert das Verfahren, führt aber kein Deployment aus.

## Update

1. Eine neue freigegebene Releaseversion auswählen und Releasebezug sowie
   Imageherkunft prüfen.
2. Den bisherigen bekannten guten Tag dokumentiert als Rollbackbasis behalten.
3. `CODESERVER_IMAGE_TAG` in Portainer auf die neue Version ändern und den
   Stackdiff prüfen.
4. Den Stack manuell neu deployen.
5. Containerstatus, Health, Loopback-Portbindung, Login, Workspace, Terminal,
   Mounts und Logs ohne Secret-Ausgabe prüfen.

Vor dem Update wird nach lokaler Betriebsfreigabe ein aktuelles Backup erstellt
und unabhängig verifiziert. Automatische GitOps-Aktualisierungen bleiben beim
ersten Cutover deaktiviert.

## Rollback

1. Den vorherigen bekannten guten Tag in `CODESERVER_IMAGE_TAG` eintragen.
2. Den Stack manuell neu deployen.
3. Persistente Daten, Secret-Datei, Backups und Restore-Testbereiche
   unverändert lassen.
4. Containerstatus, Health und dieselben Funktionen wie beim Update prüfen.

Das vorherige Image bleibt bis zum vollständig abgeschlossenen Cutover
verfügbar. Ein fehlgeschlagener Stackwechsel ist kein Anlass, persistente
Verzeichnisse oder Secrets zu löschen.

## Nicht zulässig

- `latest` oder ein impliziter Image-Tag;
- Überschreiben eines veröffentlichten Versionstags;
- automatische Updates beim ersten Cutover;
- lokale Produktivbuilds auf der Synology;
- automatische Löschung von Images, Volumes, Persistenz, Secrets oder Backups;
- ein Update oder Rollback außerhalb eines dokumentierten manuellen
  Portainer-Vorgangs.

Der detaillierte Git-Stack- und Verifikationsvertrag steht in
[SYNOLOGY-PORTAINER.md](SYNOLOGY-PORTAINER.md).
