# Support

## Unterstützter Scope

Support bezieht sich auf reproduzierbare Fehler in den versionierten Dateien
dieses Repositorys: Dockerfile, Compose-Vertrag, öffentliche Dokumentation,
Extension-Manifeste und mitgelieferte Prüfskripte.

Individuelle Synology-, Portainer-, DSM-, Reverse-Proxy-, Zertifikats-,
Firewall-, DNS- oder Netzwerk-Konfigurationen können nicht allgemein
unterstützt werden. Solche Zustände gehören zur lokalen Infrastruktur.

## Diagnoseinformationen

Eine Supportanfrage sollte mindestens enthalten:

- betroffene Repositoryversion oder Commit-ID;
- erwartetes und tatsächliches Verhalten;
- minimale reproduzierbare Schritte;
- redigierte Fehlermeldungen und Ergebnisse relevanter statischer Prüfungen;
- klare Angabe, ob der Fehler im Repository oder nur in der lokalen
  Infrastruktur auftritt.

Niemals Secrets, Passwort-Hashes, Tokens, private Domains, interne IP-Adressen,
absolute lokale Pfade oder Inhalte aus `.env` beziehungsweise `stack.env`
teilen. Bei Unsicherheit Diagnoseausgaben stärker redigieren und nur die für
die Reproduktion notwendigen Metadaten angeben.
