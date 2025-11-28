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

License: MIT (see `LICENSE`)
