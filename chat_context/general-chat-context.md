(Memory File)

# Project Overview

- Name: Lere's Guardian
- Type: Total conversion mod (Minecraft)
- Core Vision: Narrative-driven campaign with player isolation, procedural worldgen, and emergent storytelling.

## Guiding Philosophy

- placeholder for now. let's update this over time.
- capture modularity, replayability, and scalability as design ethos
 
## Core Design Principles

- Modularity — Design systems as composable modules with clearly defined interfaces. Modules should be independently testable, optionally loadable, and swappable. This reduces coupling, enables community-contributed modules, and keeps the core lean.

- Replayability & Discovery — Prioritize systems that encourage varied player experiences each run: procedural hooks, branching quest seeds, and emergent interactions. Make exploration rewarding and unpredictable within clear constraints to maximize replay value.

- Narrative Integrity — Preserve the player's sense of story even in multiplayer and procedural contexts. Use isolation/instancing, narrative anchors (biomes/seeded events), and fail-safe mechanics so story beats remain coherent despite player joins/leaves.

- Performance & Stability — Favor predictable, efficient implementations. Prioritize low-latency behavior, sane defaults for resource usage, and clear failure modes. When in doubt, prefer a simpler, stable approach over an unproven optimization.

These principles form the lightweight contract we use when making trade-offs: if a feature conflicts with two or more principles above, we require a short reasoning thread in `reasoning-context.md` that documents the trade-offs and links to the changelog.

## Priorities

- [1] Keep context files up to date, organized, and focused. Refactor when needed
- [2] Identify, isolate, and refine project goals.
- [3] Figure out the next step to our current goal.

## Current Goals

- [1] Set up base project folder and environment [Phase 1]
- [2] Define modular plugin structure [Phase 1]
- [3] Create multiplayer plugin

## Long Term Goals

- [1] Implement multiplayer (ghosts, interactions)
- [2] Make Lere plugin (ai wolf follower, interactions)
- [3] Implement multiplayer
- [4] Learn worldgen (biomes, structures)
- [5] Build narrative/quest plugin

## Design Constraints

- Must align with Minecraft's identity (block-based, chunk logic, multiplayer scaffolding).
- Performance and stability prioritized over experimental features.
- Modular systems for future reuse.

## Key Mechanics

- Player isolation (visibility filtering or instancing).
- Procedural landscapes with narrative hooks.
- Quest framework
- Magic system

## Workflow Notes

- chat_context folder = living design document + project management memory
- Use session-context.md for current work, blockers, and decisions
- Copilot acts as rubber duck and reasoning partner, keeping work on-task

## Edit Cycle Convention

Every change follows this 3-step rhythm to maintain traceability and crash-resilience:

**1. Reasoning** (if multi-step or trade-off decision)
   - Instantiate reasoning-context.md with problem, options, and constraints
   - Work through Clarify → Constraints → Options → Synthesize
   - Reach explicit decision checkpoint

**2. Decision Log** (capture decision in session-context.md)
   - Note the decision in Current Focus or add a decision marker
   - Link to reasoning-context.md if applicable
   - Keep it terse: who decided what and why in one line

**3. Changelog Entry** (durable ledger)
   - Add entry to changelog-context.md in pointer style
   - Format: `(YYYY-MM-DD, HH:MM) [What changed]. See [reasoning-context.md or session-context.md] for context.`
   - Link back to reasoning thread or session decision, don't duplicate

**Session Hygiene:**
- Prune scratchpad notes after each session close marker so they don't bloat
- Keep session-context.md focused on *current* work, not historical archive

**Reasoning Instantiation:**
- Spin up reasoning thread only for complex chains or trade-off decisions
- Use simple decisions directly without a full reasoning thread
- Archive reasoning threads if they become long; reference via changelog

## Pointer Syntax Standard

**Purpose:** Keep references between files uniform, scannable, and resilient to crashes or context loss.

**Pointer Types:**

1. **Reasoning Thread Hash:** `[#reasoning-thread-title]` <!-- example -->
   - Example: `[#plugin-architecture-tradeoff]`
   - Use when linking to a specific reasoning-context.md thread
   - Makes grep/search easy; survives file renames

2. **Session Marker:** `(Session YYYY-MM-DD HH:MM)`
   - Example: `(Session 2025-11-27 21:45)`
   - Use when referencing a decision or work block in session-context.md
   - Timestamp lets you locate the exact decision point

3. **Changelog Anchor:** `[changelog-entry:YYYY-MM-DD HH:MM]`
   - Example: `[changelog-entry:2025-11-27 22:00]`
   - Use when linking to a specific changelog entry
   - Makes traceability auditable

**Linking Rules:**

- **Session → Reasoning:** Include hash-tag when a session decision references a reasoning thread.
  - Example: "Decision: Adopt modular plugin split. See [#plugin-architecture-tradeoff]." <!-- example -->

- **Reasoning → Changelog:** At the end of a reasoning thread, log the corresponding changelog entry.
  - Example: "Logged in [changelog-entry:2025-11-27 22:00]." <!-- example -->

- **Changelog → Session/Reasoning:** Each durable entry should point back to its origin.
  - Example: "(2025-11-27, 22:00) Codified edit cycle convention. See (Session 2025-11-27 21:45) and [#edit-cycle-convention]." <!-- example -->

**Benefits:**

- Scannability: Uniform tags make references grep-able and human-readable.
- Resilience: Even mid-crash, manual checkpointing with tags keeps threads traceable.
- Archiving: Tags allow pruning or consolidating reasoning threads without losing linkage.

## Governance Framework for Changes

**Changelog as ledger:**
- Every structural change logged with reasoning pointer
- Human-readable commit history
- Pointer style: reference session or reasoning threads instead of duplicating

**Session-context.md as scratchpad:**
- Ephemeral notes, active decisions, thinking-in-the-moment
- Can be pruned or archived after each reboot
- Useful for continuity but not meant to be permanent history

**Reasoning-context.md as scaffold:**
- Instantiated only when tackling multi-step or complex trade-off problems
- Captures structured thinking with options and decision rationale
- Referenced by changelog entries for traceability

**General-chat-context.md as anchor:**
- Keeps the "why" visible: vision, philosophy, design constraints
- Updated when project direction or priorities shift
- Copilot uses this to stay aligned with project ethos

## Notes for Copilot

- Treat this as a Minecraft mod project.
- Use Fabric API conventions unless otherwise specified.
- Keep code modular and clean for future reuse.
- When in doubt, prioritize stability and performance.

## Project Folder Structure

Record of the top-level folders in this workspace and their purpose. Keep this updated when creating new major artifacts.

```
Lere/                      # project root
├─ chat_context/           # persistent session & design memory (this folder)
│  ├─ changelog-context.md
│  ├─ reasoning-context.md
│  ├─ session-context.md
│  └─ ...
├─ datapacks/               # datapacks for the project
│  └─ lere_guardian/        # Phase 1 datapack scaffold
├─ plugins/                 # server plugin source & scaffolds
│  └─ lere_core/            # prototype Paper plugin scaffold (zone commands)
├─ docs/                    # optional design docs and exportable notes
└─ README.md
```

Notes:
- Keep `chat_context/` as the authoritative memory; update file pointers when moving files.
- For distribution, package `plugins/` JARs and `datapacks/lere_guardian` as a single release archive (Phase 1 target < 50MB).

## Audit Checklist (lightweight)

Purpose: a short, repeatable checklist to keep pointer/linkage hygiene and changelog/session sync healthy. Run this before major releases or monthly.

- 1) Gather pointer evidence
   - Search for reasoning-thread hashes: `[#... ]` across `chat_context` and list unique tags.
   - Search for changelog anchors: `[changelog-entry:YYYY-MM-DD HH:MM]` and session markers `(Session YYYY-MM-DD HH:MM)`.

- 2) Orphan check
   - For each reasoning-thread hash found, confirm a corresponding stub exists in `reasoning-context.md`.
   - For each changelog anchor found, confirm the referenced changelog line exists and links to a session or reasoning thread.

- 3) Formatting checks
   - Ensure pointer tags match the canonical regex patterns documented below.
   - Confirm hyphen bullet style (`-`) is used across the file set.

- 4) Actions on orphans
   - If a hash is orphaned and intended to be real: create a short stub in `reasoning-context.md` and add a changelog anchor to the relevant changelog entry.
   - If a hash is an example/demo, mark it with `<!-- example -->` on the same line to avoid future false positives.

- 5) Record audit results
   - Create a short session note (Session YYYY-MM-DD HH:MM) summarizing findings and link any created stubs with `[#thread]` and `[changelog-entry:...]` anchors.

Canonical regex patterns (PowerShell examples):

```powershell
# Find reasoning-thread hashes
Get-ChildItem -Path "c:\Users\Eris\Dropbox\Dev\Lere\chat_context" -Recurse -Include *.md |
   Select-String -Pattern '\[#([^\]]+)\]' | Select-Object Path,LineNumber,Line

# Find changelog anchors
Get-ChildItem -Path "c:\Users\Eris\Dropbox\Dev\Lere\chat_context" -Recurse -Include *.md |
   Select-String -Pattern '\[changelog-entry:\d{4}-\d{2}-\d{2} \d{2}:\d{2}\]' | Select-Object Path,LineNumber,Line

# Find session markers
Get-ChildItem -Path "c:\Users\Eris\Dropbox\Dev\Lere\chat_context" -Recurse -Include *.md |
   Select-String -Pattern '\(Session \d{4}-\d{2}-\d{2} \d{2}:\d{2}\)' | Select-Object Path,LineNumber,Line
```

Cadence & ownership:

- Cadence: monthly and before major releases.  
- Owner: designated reviewer (project maintainer or person running the release); Copilot can run the audit on request and produce an orphan-report.

