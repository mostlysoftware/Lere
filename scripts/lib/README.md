Project scripts library

This folder contains small library helpers used by the project's maintenance scripts.

Key files

- `ProjectConfig.ps1` — centralized configuration for health checks, duplicate scanning, and audit outputs. Edit here to tune thresholds and excludes for the whole project.
- `DuplicateContent.ps1` — functions to detect duplicated blocks across files: `Get-DuplicateBlocks` and `Write-DuplicateReport`.
- `Show-ProjectConfig.ps1` — helper to print the active project config and quick commands for new contributors.

Quickstart for new contributors

1. Print the active configuration and quick commands:
   - PowerShell: `.	ools\pwsh -NoProfile -File .\scripts\lib\Show-ProjectConfig.ps1` (or simply run the script in a PowerShell session).
2. Run the health check (console):
   - `.	ests\pwsh -NoProfile -File .\scripts\health_check.ps1 -Scope all -Report console`
3. Review JSON reports in `scripts/audit-data/`.

Onboarding notes

- Memory files (LLM context) are under `chat_context/`. Each memory file should start with the exact text `(Memory File)` on the first line.
- Use `ProjectConfig.ps1` to tune duplicate detection sensitivity and to add paths to exclude (for example, `scripts/lib` and `chat_context/archives` are ignored by default).

If you make changes to `ProjectConfig.ps1`, re-run `health_check.ps1` to see the effects.
