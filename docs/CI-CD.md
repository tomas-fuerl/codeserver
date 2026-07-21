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
öffentlichen temporären Testwerten und baut `linux/amd64` ohne Load, Push,
SBOM oder Attestation. Buildx verwendet den GitHub-Actions-Cache. Es gibt
keinen Registry-Login und keine schreibende Tokenberechtigung.

Der Docker-Buildkontext wird durch eine restriktive `.dockerignore`-Allowlist
begrenzt. Da das Dockerfile keine lokalen `COPY`- oder `ADD`-Eingaben besitzt,
sind nur `Dockerfile` und `.dockerignore` freigegeben. `.gitignore` steuert
dagegen ausschließlich, welche lokalen Dateien Git nicht versioniert; es ist
kein Schutz für den Docker-Buildkontext. Das Repositorygate prüft beide
Verträge ohne Docker-Daemon.

Zusätzlich erzwingen die daemonfreien Freeze-Gates eine versionierte und
digestgepinnte LinuxServer-Basis, das öffentliche OCI-Source-Label, ausschließlich
öffentliche Werkzeugquellen, ausführbare Shellskripte, finale LF-Zeilenumbrüche
sowie konsistente und explizit versionierte Extension-Lockeinträge.

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

Der Publish-Build unterstützt zunächst ausschließlich `linux/amd64`, nutzt
den GitHub-Actions-Cache, erzeugt eine SBOM und deaktiviert die in Buildx
eingebettete Provenienz. Anschließend attestiert `actions/attest` den
ungekennzeichneten Image-Namen gegen den tatsächlich erzeugten Build-Digest
und veröffentlicht die Provenienz-Attestation in der Registry.

Der vollständige Image-Digest ist die stärkste unveränderliche
Deploymentidentität. Die spätere Freigabe prüft Tag, Commit, Digest, SBOM und
Attestation gemeinsam. `linux/arm64` darf erst nach separater Build- und
Laufzeitvalidierung ergänzt werden.

Die GHCR-Package-Sichtbarkeit ist kein lokaler Repositoryzustand. Falls das
erste Package nach MIG-010 privat ist, steuert EXT-003 die manuelle
Sichtbarkeitsänderung. Der Zielarchitektur-Nachweis wird über EXT-009 geführt.

## Action-Pinning

Alle externen Actions sind auf vollständige 40-stellige Commit-SHAs gepinnt.
Der Kommentar hinter jedem Pin nennt die geprüfte Releaseversion. Updates
werden nur als reviewpflichtige Dependabot-Vorschläge erzeugt; ein
Versionskommentar und der zugehörige SHA müssen gemeinsam geprüft werden.
