# Lere's Guardian

Repository mirror of the Lere's Guardian project.

Structure

- `chat_context/` — persistent session & design memory files (changelog, reasoning, session, etc.)
- `datapacks/` — datapack scaffolds and content (Phase 1: `lere_guardian`)
- `plugins/` — server plugin source and scaffolds (Phase 1: `lere_core`)
- `scripts/` — utility and audit scripts
- `.github/` — CI workflows and metadata

Purpose

This repo holds the source artifacts (datapack, plugin scaffolds) and the in-repo memory (`chat_context`) so project state is versioned and auditable.

Guidance

- Keep `chat_context/` updated as the canonical session memory.
- Use the `scripts/audit.ps1` audit script before major commits or releases.
- Build plugins locally and test on a dev Paper server before publishing releases.

Quickstart (TL;DR)

- Run pointer audit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\audit.ps1"
```

- Build plugins (from project root):

```powershell
.\plugins\lere_multiplayer\gradlew.bat build
.\plugins\lere_core\gradlew.bat build
```

- Package datapack for testing:

```powershell
Compress-Archive -Path .\datapacks\lere_guardian\* -DestinationPath .\release\lere_guardian_datapack.zip -Force
```

For the full onboarding quick-start (detailed steps, troubleshooting, and 2-player test plan) see `chat_context/onboarding.md`.

Dev helper

If you prefer one command to run audit → build → package (useful for local iteration), run the helper script from the project root:

```powershell
.\scripts\dev-run.ps1
# skip datapack packaging during quick validation:
.\scripts\dev-run.ps1 -SkipDatapack
```

First-time setup (recommended)
------------------------------

After you clone or pull the repository for the first time, run the interactive first-time helper. It probes your environment, runs repository health checks, offers to install Git hooks, and can perform user-local JDK installation and an initial build.

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\first_time_setup.ps1
```

When you're done, copy the output into the AI assistant and ask: "Any additional first-time setup tasks for my environment?" — the assistant will suggest any missing tools or steps specific to your machine.

License: MIT (see `LICENSE`)
