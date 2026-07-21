# Releases

## Versionierungsvertrag

Öffentliche Release-Tags folgen strikt:

```text
vMAJOR.MINOR.PATCH
```

Ein Release darf erst nach erfolgreichem MIG-006 sowie nach Veröffentlichung
und Schutz des Repositorys in MIG-009 vorbereitet werden. Das erste
GHCR-Artefakt entsteht in MIG-010.

Für `v1.4.0` erzeugt der Publish-Workflow ausschließlich:

```text
1.4.0
sha-<full-commit>
```

Der Patchtag `1.4.0` ist die primäre lesbare Deploymentreferenz. Der
vollständige Image-Digest ist die stärkste unveränderliche Referenz.
`MAJOR.MINOR`, `MAJOR`, `latest` und ein Imagetag mit führendem `v` werden
nicht erzeugt.

## Unveränderliche Artefakte

- Git- und Image-Tags werden nur einmal veröffentlicht und nie überschrieben.
- Es wird kein `MAJOR.MINOR`, `MAJOR`, `latest`, `main`, `edge` oder
  `v`-präfixiertes Imagetag erzeugt.
- Release-Commit, erzeugte Tags und Image-Digest werden gemeinsam dokumentiert.
- Portainer und andere Deployments verwenden einen freigegebenen vollständigen
  Patch-Tag oder direkt den geprüften Digest.
- Ein falsches oder fehlgeschlagenes Artefakt wird nicht durch Verschieben
  eines vorhandenen Tags korrigiert.

Die restriktive `.dockerignore` begrenzt den Buildkontext auf nachgewiesene
Dockerfile-Eingaben. `.gitignore` verhindert lediglich die Git-Versionierung
lokaler Dateien und ersetzt diese Buildkontextkontrolle nicht.

## Publish-Vertrag

Nur ein gültiger Git-Tag `vMAJOR.MINOR.PATCH` kann den Workflow auslösen.
Die strikte SemVer-Prüfung erfolgt vor dem GHCR-Login. Der Workflow baut
`linux/amd64`, veröffentlicht eine SBOM und erzeugt eine
Provenienz-Attestation für den Build-Digest. Weitere Details stehen unter
[CI und Container-Publishing](CI-CD.md).

## Rollback

Für einen Rollback wählt Portainer die zuvor freigegebene unveränderliche
Patchversion beziehungsweise deren Digest. Persistente Daten und Secrets
bleiben außerhalb des Images erhalten. Vorhandene Tags werden beim Rollback
nicht verändert.
