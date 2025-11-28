# Consolidated summaries - 2025-11-28

This file was generated to consolidate top-level `*.summary.md` files from `chat_context/` into a single artifact. Each section below preserves the original summary content with a provenance header.

---

## Source: ATTACHMENTS.summary.md

```markdown
<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\ATTACHMENTS.md -->
<!-- lines: 7 -->

 (Memory File)

## Attachments

This is a small memory file listing attachments referenced across sessions and reasoning threads.

- No sensitive attachments are stored in this repo. If you add attachments, reference them by relative path and ensure they are covered by the project's license and privacy policy.

```

---

## Source: gameplay-context.summary.md

```markdown
<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\gameplay-context.md -->
<!-- lines: 38 -->

(Memory File)

# Gameplay Context

**Purpose:** Narrative design, player mechanics, progression systems, and gameplay loops.

---

## Narrative Context

| Aspect | Notes |
|--------|-------|
| Story arcs | Thematic progression, main arc vs sidequests |
| Player agency | Authored experience vs emergent choices |
| Quest structure | Branching logic, biome-triggered quests |
| Dialogue systems | Delivery mechanisms, NPC interactions |

## Narrative Layers

- main arc
- sidequests
- emergent events
- character progression
- relationship to companion npc progression

## Player Context

- Player roles and gameplay expectations
- Isolation mechanics (visibility filtering, instancing, phasing)
- Progression systems and reward loops
- Social dynamics and emergent behavior
- Accessibility and onboarding strategies


## Progression Framework
- levels
- achievements
- unlocks

```

---

## Source: knowledge-compartmentalization.summary.md

```markdown
<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\knowledge-compartmentalization.md -->
<!-- lines: 36 -->

(Memory File)

# Knowledge Compartmentalization Map

**Purpose:** Describe how to keep high-level context crisp while offloading deep details so the assistant can decide when to request extra knowledge.

---

## Strategy

1. **Summaries stay front and center:** Each context file keeps a concise overview of its topic. When detail grows beyond what the summary can absorb, it is moved into a dedicated offload file.
2. **Offload files live under `chat_context/archives/` or in-purpose subfiles:** They capture granular trade-offs, audit findings, or extended reasoning without cluttering the active context.
3. **Reference the offload path:** Summary sections link to the offload file using pointer tags so an LLM can decide, "Do I need that level of detail?" before requesting it.
4. **Document the trigger:** This map records why each topic was offloaded and when to fetch it (e.g., "If you need pointer syntax rules, request `chat_context/offloads/pointer-guidelines.md`." ).

## Offload index (examples)

| Topic | Summary location | Offload file | When to request |
|-------|------------------|--------------|-----------------|
| Audit checklist & pointer syntax | `chat_context/general-chat-context.md` (Section "Audit Checklist" / "Pointer Syntax") | `chat_context/offloads/pointer-guidelines.md` | When explaining pointer conventions or verifying health-check output references.
| Session cleanup heuristics | `chat_context/session-context.md` (active sessions) | `chat_context/archives/session-cleanup-notes.md` | When asked about archiving strategies or pruning rules beyond current sessions.
| Technical constraints & plugin scaffolding | `chat_context/technical-context.md` | `chat_context/archives/technical-deep-dive.md` | When the conversation requires low-level config, dependencies, or environment assumptions.
| Open questions backlog | `chat_context/open-questions-context.md` | `chat_context/archives/questions-archive-20251128-024538.md` | When reviewing deferred questions or examining how past answers evolved.
| Question prioritization playbook | `chat_context/open-questions-context.md` (Open Questions section) | `chat_context/archives/question-prioritization-2025-11.md` | When triaging new questions or deciding which backlog items to escalate.

## How to request offloaded knowledge

- Mention the desired topic and its offload file (or pointer tag) in your query: e.g., "Request pointer syntax details from `knowledge-compartmentalization.md` -> `pointer-guidelines.md`."
- If you only need a brief recap, cite the summary location and ask for a deeper dive if certain conditions apply.
- Treat this map as the directory of knowledge compartments; the assistant can stay brief unless the map specifically lets it escalate the detail level.

## Proactive Notes for Copilot

- Before overloading responses with deep detail, check this map and ask whether the user wants the offload file referenced.
- Use pointer tags (!) when referencing offloaded sections to keep future audits traceable (e.g., `[#pointer-guidelines] <!-- example -->`).
- Update this map whenever a new offload file is created or summaries shift shape.

```

---

## Source: general-chat-context.summary.md

```markdown
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

```

---

## Source: changelog-context.summary.md

```markdown
<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\changelog-context.md -->
<!-- lines: 46 -->

(Memory File)

# Changelog Context

**Purpose:** Durable ledger of structural changes, decisions, and file edits.

---

## Governance Rules
- Every structural change gets logged here with a brief description
- Point to reasoning-context.md when decisions involved trade-offs
- Use "pointer style": reference session notes rather than duplicating reasoning
- Prune inconsequential entries to keep the log concise and scannable
- Use Pointer Syntax Standard: [#reasoning-thread] <!-- example -->, (Session YYYY-MM-DD HH:MM), [changelog-entry:YYYY-MM-DD HH:MM]
- Format: `(YYYY-MM-DD, HH:MM) [Change summary]. See [#pointer] <!-- example --> or (Session YYYY-MM-DD HH:MM).`

## Changes

- (2025-11-28, 03:34) Added Context Hygiene Policies to `general-chat-context.md`: Philosophy Refinement (quarterly review triggers, conflict detection, refinement process), Open Questions Triage (monthly cadence, status definitions, priority tagging), Bloat Prevention (file limits, archive hygiene, session pruning). Enhanced `health_check.ps1` with Hygiene Prompts section showing philosophy age, questions triage status, and bloat summary. Created `schedule_health_check.ps1` for Windows Task Scheduler setup and `.github/workflows/health-check.yml` for weekly CI runs. See (Session 2025-11-28 03:00). [changelog-entry:2025-11-28 03:34]

*...preview truncated; full content available on demand.*

```

---

## Source: technical-context.summary.md

```markdown
<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\technical-context.md -->
<!-- lines: 170 -->

(Memory File)

# Technical Context

**Purpose:** Environment setup, hosting strategies, migration notes, and performance benchmarks. Keeps infrastructure separate from design.

---

## Hosting Strategy

- Likely digital ocean for affordability, with possibility of transition to AWS or similar if needs evolve.

### Minimum Viable Hosting Setup

This is the resolved answer to the open question about the minimum viable hosting setup for testing Phase 1.

- **Baseline hardware**: 2 vCPUs, 4â€“8 GB RAM (start at 4 GB; upgrade if Paper server consistently hits >3 GB heap), 60 GB SSD, and 1 Gbps net. Use a low-cost provider (DigitalOcean Basic/General Purpose, Hetzner CX31, or Azure B1ms) so the team can spin spin up/down quickly.
- **Operating system**: Ubuntu 24.04 LTS (or Windows Server 2022 if Windows-specific tooling is required). Keep the host minimal (no GUI) and apply unattended upgrades from day 1.

*...preview truncated; full content available on demand.*

```

---

## Source: session-context.summary.md

```markdown
````markdown
<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\session-context.md -->
<!-- lines: 287 -->

(Memory File)

# Session Context

**Purpose:** Lightweight scratchpad for per-session decisions. Archive when useful; prune when stale.

---

## Session Template (Kickoff / Close)

- Purpose: Use these snippets to quickly start and close sessions with consistent metadata and links.
- Metadata format: Unified HTML comment block parsed by pruner scripts (see `scripts/lib/Parse-EntryMetadata.ps1`).

*...preview truncated; full content available on demand.*

````

---

## Source: reasoning-context.summary.md

```markdown
````markdown
<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\reasoning-context.md -->
<!-- lines: 129 -->

(Memory File)

# Reasoning Context

**Purpose:** Long-form reasoning threads for design decisions and trade-offs. One thread per major decision; reference from session-context.md when active.

*...preview truncated; full content available on demand.*

````

---

## Source: README.summary.md

```markdown
````markdown
<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\README.md -->
<!-- lines: 79 -->

# chat_context README

This folder holds the project's in-repo assistant memory and governance artifacts.

*...preview truncated; full content available on demand.*

````

---

## Source: PRIVACY.summary.md

```markdown
<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\PRIVACY.md -->
<!-- lines: 9 -->

 (Memory File)

## Privacy Notes

This file documents the project's privacy considerations for stored context and audit outputs.

- Ensure audit artifacts do not leak personal data.
- Audit reports are stored in `scripts/audit-data` and rotated/archived regularly.
- Sensitive patterns (emails, user paths) are detected and reported by `scripts/audit.ps1`.

```

---

## Source: plugin-context.summary.md

```markdown
<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\plugin-context.md -->
<!-- lines: 33 -->

(Memory File)

# Plugin Context

**Purpose:** Plugin architecture, compatibility notes, dependencies, and integration patterns.

*...preview truncated; full content available on demand.*

```

---

## Source: open-questions-context.summary.md

```markdown
````markdown
<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\open-questions-context.md -->
<!-- lines: 72 -->

(Memory File)

# Open Questions Context

**Purpose:** Unified backlog of unresolved questions, grouped by source file.

*...preview truncated; full content available on demand.*

````

---

(End of consolidated file)
