# Mitwirken

Beiträge sind willkommen, wenn sie klein, nachvollziehbar und ohne lokale
Betriebswerte bleiben.

## Ablauf

1. Vor der Änderung ein Issue oder einen eindeutig freigegebenen Task
   verwenden.
2. Auf einem Feature-Branch arbeiten; nicht direkt auf dem Default-Branch.
3. Keine Secrets, privaten Pfade, realen Infrastrukturwerte, `.env`- oder
   `stack.env`-Dateien einbringen.
4. Das lokale Qualitätsgate vom Repository-Root ausführen:

   ```bash
   ./scripts/ci/validate-repository.sh
   ```

5. Einen Pull Request mit Scope, Prüfergebnissen, Restrisiken und
   Rollbackhinweis eröffnen.

Das Gate prüft Shellsyntax und ShellCheck, statische Installation,
Publication-Audit, Workflowverträge, relative Markdown-Links, Konfliktmarker,
verbotene Artefakte, das eindeutige Compose-Layout und die restriktive
`.dockerignore`-Allowlist. Es führt keine Container-, Netzwerk- oder
Deploymentaktion aus.

Neue lokale `COPY`- oder `ADD`-Eingaben im Dockerfile erfordern eine explizite,
reviewte Freigabe in `.dockerignore`; Verzeichnisse und benötigte Unterpfade
müssen einzeln nachvollziehbar bleiben. `.gitignore` steuert nur die
Git-Versionierung und ersetzt diese Buildkontext-Allowlist nicht. Der
Releasevertrag erzeugt ausschließlich `MAJOR.MINOR.PATCH` und
`sha-<full-commit>`; `MAJOR.MINOR`, `MAJOR`, `latest` und führendes `v` sind
als Imagetags unzulässig.

Dependabot-Änderungen sind normale, reviewpflichtige Pull Requests. Gepinnter
Action-SHA und Versionskommentar müssen gemeinsam gegen das offizielle
Ursprungsrepository geprüft werden; es gibt kein automatisches Merge.

Ein Pull Request führt keine direkte produktive Deploymentaktion aus. Änderungen
an Portainer, Synology DSM, Reverse Proxy, Firewall, Secrets oder laufenden
Containern benötigen einen getrennten, ausdrücklich freigegebenen
Betriebsablauf.
