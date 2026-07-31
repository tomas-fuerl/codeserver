# CI und Container-Publishing

## Lokale Definition, noch kein Online-Nachweis

Die beiden Workflows sind im Arbeitsbaum definiert, werden aber erst nach dem
initialen Push in MIG-009 auf GitHub ausführbar. MIG-005 führt keinen Workflow
aus. Das erste veröffentlichte Image entsteht frühestens in MIG-010.

## CI-Workflow

`.github/workflows/ci.yml` läuft für Pull Requests gegen `main`, Pushes auf
`main` und manuelle `workflow_dispatch`-Aufrufe. Er besitzt auf
Workflowebene ausschließlich `contents: read`, verwendet GitHub-hosted
Runner und bricht ältere Läufe derselben Workflow-/Ref-Gruppe ab.

Der einzige primäre Job führt das lokale Gate
`./scripts/ci/validate-repository.sh` aus, rendert `compose.yaml` nur mit
öffentlichen temporären Testwerten und richtet die offizielle, vollständige
QEMU-Action `docker/setup-qemu-action@96fe6ef7f33517b61c61be40b68a1882f3264fb8`
(`v4.2.0`) sowie die offizielle Aqua-Action
`aquasecurity/setup-trivy@81e514348e19b6112ce2a7e3ecbafe19c1e1f567`
(`v0.3.1`) ein und installiert ausdrücklich Trivy `v0.72.0`; unmittelbar
nach der Installation wird `trivy --version` exakt geprüft. Danach baut er den Dockerfile vollständig für `linux/amd64`
und `linux/arm64` ohne Push oder Registry-Login. Der `amd64`-Build wird für
den isolierten Runtime-Smoke-Test geladen; der `arm64`-Build wird als OCI-
Archiv für den tatsächlichen Trivy-Image-Scan erzeugt. Buildx verwendet den
GitHub-Actions-Cache. Es gibt keine schreibende Tokenberechtigung und keine
Secrets.

Der normale LinuxServer-Einstiegspunkt wird zusätzlich mit synthetischer `/config`- und Passwort-Hash-Datei gestartet: CI prüft Healthcheck, PUID/PGID-Ownership, Nicht-Root-Dienst, `/config`-Persistenz nach Neustart sowie das Fehlen von Socket und Daemons.

Der Runtime-Smoke-Test überschreibt den Entry Point und prüft Node, pnpm,
PostgreSQL-Clients, Docker CLI, Compose V2, Buildx und Trivy. Er verwendet
keine Mounts, Secrets oder Netzwerkfreigaben und bestätigt, dass Docker-Socket,
`dockerd` und `containerd` fehlen. `scripts/ci/run-trivy-scan.sh` scannt danach
den Repository-Dateisystem-/Konfigurationsstand und beide tatsächlich
gebauten Architekturartefakte. Das Skript schreibt nur eine restriktive
temporäre JSON-Datei, gibt keine Secret-Matches aus und beendet sich bei
`HIGH`/`CRITICAL` mit Exit-Code 1; Scannerfehler liefern Exit-Code 2.
AMD64- und ARM64-Scans laufen unabhängig mit `if: always()`/`continue-on-error`;
der abschließende Gate-Schritt schlägt bei Status 1 oder 2 fehl. Der Scanner
lädt ausschließlich deterministisch sortierte, sanitiserte Vulnerability-Felder
und getrennte Fix-/No-Fix-/Direkttool-/Basisimage-Counts als CI-Artefakt hoch;
Secret-Scans liefern nur Anzahl und Status.

Der Docker-Buildkontext wird durch eine restriktive `.dockerignore`-Allowlist
begrenzt. Da das Dockerfile keine lokalen `COPY`- oder `ADD`-Eingaben besitzt,
sind nur `Dockerfile` und `.dockerignore` freigegeben. `.gitignore` steuert
dagegen ausschließlich, welche lokalen Dateien Git nicht versioniert; es ist
kein Schutz für den Docker-Buildkontext. Das Repositorygate prüft beide
Verträge ohne Docker-Daemon.

Zusätzlich erzwingen die daemonfreien Freeze-Gates eine versionierte und
digestgepinnte LinuxServer-Basis, das öffentliche OCI-Source-Label, ausschließlich
offizielle und checksum-/integrity-verifizierte Werkzeugquellen, die PGDG-/Docker-
Keyring-Fingerprints, ausführbare Shellskripte, finale LF-Zeilenumbrüche sowie
konsistente und explizit versionierte Extension-Lockeinträge. Ein fehlender
Docker-Daemon oder Socket ist dabei ein gewünschtes Ergebnis.

## Publish-Workflow

`.github/workflows/publish-image.yml` reagiert ausschließlich auf Tags, die
dem Trigger `v*.*.*` entsprechen. Vor dem Registry-Login erzwingt ein
zusätzliches Gate exakt:

```text
vMAJOR.MINOR.PATCH
```

Führende Nullen, Prerelease-Suffixe, verkürzte Versionen und unversionierte
Namen werden abgewiesen. Der Publish-Job erhält genau `contents: read`,
`packages: write`, `attestations: write` und `id-token: write`.

Die Anmeldung an `ghcr.io` verwendet ausschließlich den Actor und das
kurzlebige `GITHUB_TOKEN`. Es gibt keinen Personal Access Token und kein
zusätzliches Registry-Secret.

`docker/metadata-action` verwendet den expliziten Flavor `latest=false`.
Damit wird kein `latest`-Tag veröffentlicht. Die Flavor-Konfiguration enthält
weder Stringverkettung noch dynamische GitHub-Expressionen; aktive Imagetags
bleiben ausschließlich Patch-SemVer und der lange Commit-SHA.

Aus `v1.4.0` entstehen ausschließlich:

- `ghcr.io/tomas-fuerl/codeserver:1.4.0`;
- `ghcr.io/tomas-fuerl/codeserver:sha-<full-commit>`.

Es gibt weder `MAJOR.MINOR`, `MAJOR`, `latest`, `main`, `edge` noch ein
Imagetag mit führendem `v`. OCI-Labels dokumentieren Quelle, Revision, Version
und MIT-Lizenz. Portainer verwendet den vollständigen Patch-Tag; der Digest
bleibt die stärkste unveränderliche Deploymentreferenz.

## Artefakte und Identität

Der Publish-Build bleibt aus Scopegründen auf `linux/amd64` begrenzt und
ändert die bestehende Release-/Taglogik nicht. Der PR-CI-Nachweis deckt bereits
beide Architekturen ab; ein späterer Publish-Architekturwechsel benötigt einen
separaten Review. Der Publish-Build nutzt den GitHub-Actions-Cache, erzeugt eine
SBOM und deaktiviert die in Buildx eingebettete Provenienz. Anschließend attestiert `actions/attest` den
ungekennzeichneten Image-Namen gegen den tatsächlich erzeugten Build-Digest
und veröffentlicht die Provenienz-Attestation in der Registry.

Der vollständige Image-Digest ist die stärkste unveränderliche
Deploymentidentität. Die spätere Freigabe prüft Tag, Commit, Digest, SBOM und
Attestation gemeinsam. Die PR-CI liefert den separaten `linux/arm64`-
Buildnachweis; eine ARM64-Laufzeitabnahme bleibt außerhalb dieses PR-Runners.

Die GHCR-Package-Sichtbarkeit ist kein lokaler Repositoryzustand. Falls das
erste Package nach MIG-010 privat ist, steuert EXT-003 die manuelle
Sichtbarkeitsänderung. Der Zielarchitektur-Nachweis wird über EXT-009 geführt.

## Action-Pinning

Alle externen Actions sind auf vollständige 40-stellige Commit-SHAs gepinnt.
Der Kommentar hinter jedem Pin nennt die geprüfte Releaseversion. Updates
werden nur als reviewpflichtige Dependabot-Vorschläge erzeugt; ein
Versionskommentar und der zugehörige SHA müssen gemeinsam geprüft werden.
