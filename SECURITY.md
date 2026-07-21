# Security Policy

## Sicherheitslücken melden

Sicherheitslücken bitte nicht als öffentliches Issue melden. Sobald das
Repository veröffentlicht ist, soll dafür GitHubs private
Security-Advisory-Funktion des Repositorys verwendet werden.

Keine Passwörter, Tokens, API-Schlüssel, Passwort-Hashes, `.env`-Inhalte oder
andere Secrets in Issues, Pull Requests, Advisory-Beschreibungen oder Logs
einfügen. Diagnoseausgaben müssen vor dem Teilen redigiert werden.

## Workflow- und Supply-Chain-Schutz

Externe GitHub Actions sind auf vollständige Commit-SHAs gepinnt; ein
Versionskommentar dokumentiert die verifizierte Releasebasis. Workflowtoken
erhalten nur die je Job notwendigen Berechtigungen. CI ist read-only. Der
Publish-Job verwendet für GHCR ausschließlich das kurzlebige
`GITHUB_TOKEN`, keinen Personal Access Token.

Eine restriktive `.dockerignore`-Allowlist schließt den gesamten Buildkontext
zunächst aus und gibt nur nachgewiesene Dockerfile-Eingaben frei. Damit werden
Repository-Metadaten, Dokumentation und lokaler Zustand nicht versehentlich an
den Builder übertragen. `.gitignore` begrenzt nur die Git-Versionierung und ist
kein Ersatz für diese Buildkontextkontrolle.

Das Releaseimage wird gegen seinen Build-Digest attestiert und mit einer SBOM
veröffentlicht. Vor einem Deployment sind Digest, Herkunft und Attestation zu
prüfen. Ein Tag allein ist kein gleich starker Identitätsnachweis wie der
Digest. Der Publish-Vertrag erzeugt ausschließlich den vollständigen
`MAJOR.MINOR.PATCH`-Tag und `sha-<full-commit>`; `MAJOR.MINOR`, `MAJOR`,
`latest` und führendes `v` sind ausgeschlossen. Portainer verwendet den
vollständigen Patch-Tag oder direkt den verifizierten Digest.

Dependabot schlägt Action- und Docker-Updates monatlich vor. Diese Vorschläge
werden weder automatisch zusammengeführt noch automatisch freigegeben;
Release, SHA-Pin und Änderungsumfang benötigen Review.

## Unterstützte Versionen

Unterstützte Versionen werden erst nach dem ersten öffentlichen Release
verbindlich ausgewiesen. Vorher begründen Entwicklungs- oder
Migrationsartefakte keinen produktiven Supportstatus.

## Betreiberverantwortung

Die Sicherheit lokaler Synology-, Portainer-, Secret-, Reverse-Proxy-,
Zertifikats-, Netzwerk- und Firewallkonfigurationen liegt beim jeweiligen
Betreiber. Dieses Repository dokumentiert öffentliche Anforderungen, enthält
aber weder lokale Werte noch einen Nachweis des produktiven Zustands.
