<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\general-chat-context.md -->
<!-- lines: 253 -->

(Memory File)

# General Chat Context

**Purpose:** Project philosophy, design principles, priorities, and cross-cutting governance rules.

---

## Project Overview

| Key | Value |
|-----|-------|
| **Name** | Lere's Guardian |
| **Type** | Total conversion mod (Minecraft) |
| **Vision** | Narrative-driven campaign with player isolation, procedural worldgen, and emergent storytelling |

## Guiding Philosophy

- Project minimalism: prefer minimal viable implementations, avoid unnecessary features and repository bloat; keep artifacts small and focused.
- Modularity, replayability, and scalability as design ethos.

## Core Design Principles

- Modularity â€” Design systems as composable modules with clearly defined interfaces. Modules should be independently testable, optionally loadable, and swappable. This reduces coupling, enables community-contributed modules, and keeps the core lean.

- Replayability & Discovery â€” Prioritize systems that encourage varied player experiences each run: procedural hooks, branching quest seeds, and emergent interactions. Make exploration rewarding and unpredictable within clear constraints to maximize replay value.

- Narrative Integrity â€” Preserve the player's sense of story even in multiplayer and procedural contexts. Use isolation/instancing, narrative anchors (biomes/seeded events), and fail-safe mechanics so story beats remain coherent despite player joins/leaves.

- Performance & Stability â€” Favor predictable, efficient implementations. Prioritize low-latency behavior, sane defaults for resource usage, and clear failure modes. When in doubt, prefer a simpler, stable approach over an unproven optimization.

## Privacy & anonymization rule

We keep `chat_context/` free of personal identifiers (names, emails, or local OS user paths). See `privacy.md` for the canonical policy and sanitization guidance. Short rules:

- Replace personal names with the single placeholder `user`.
- Avoid absolute OS paths containing real usernames; use `C:\\Users\\user\\...` or `<USER_HOME>` instead.
- Run `scripts/audit.ps1` before committing to validate pointer hygiene and that no forbidden identifiers are present.

These principles form the lightweight contract we use when making trade-offs: if a feature conflicts with two or more principles above, we require a short reasoning thread in `reasoning-context.md` that documents the trade-offs and links to the changelog.

*...preview truncated; full content available on demand.*


