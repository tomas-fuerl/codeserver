# Arbeitsregeln für Repository-Agenten

- Vor jeder Änderung `TASK.md` vollständig lesen.
- Immer genau einen Migrationstask bearbeiten.
- Vor Beginn Status, Abhängigkeiten und External-Action-Gates prüfen.
- Externe Aktionen ausschließlich über
  [docs/migration/EXTERNAL-ACTIONS.md](docs/migration/EXTERNAL-ACTIONS.md)
  steuern.
- Keine Secrets, privaten Werte oder Inhalte lokaler Environment-Dateien lesen
  oder ausgeben.
- Keine Commits ohne ausdrückliche Freigabe erstellen.
- Den freigegebenen Scope nicht stillschweigend erweitern.
- Jede Bearbeitung mit einem lokalen `TASK-RESULT.md` abschließen.
- Das verbindliche
  [Codex-Protokoll](docs/migration/CODEX-PROTOCOL.md) einhalten.
