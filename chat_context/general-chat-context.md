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

- Modularity — Design systems as composable modules with clearly defined interfaces. Modules should be independently testable, optionally loadable, and swappable. This reduces coupling, enables community-contributed modules, and keeps the core lean.

- Replayability & Discovery — Prioritize systems that encourage varied player experiences each run: procedural hooks, branching quest seeds, and emergent interactions. Make exploration rewarding and unpredictable within clear constraints to maximize replay value.

- Narrative Integrity — Preserve the player's sense of story even in multiplayer and procedural contexts. Use isolation/instancing, narrative anchors (biomes/seeded events), and fail-safe mechanics so story beats remain coherent despite player joins/leaves.

- Performance & Stability — Favor predictable, efficient implementations. Prioritize low-latency behavior, sane defaults for resource usage, and clear failure modes. When in doubt, prefer a simpler, stable approach over an unproven optimization.

## Privacy & anonymization rule

We keep `chat_context/` free of personal identifiers (names, emails, or local OS user paths). See `privacy.md` for the canonical policy and sanitization guidance. Short rules:

- Replace personal names with the single placeholder `user`.
- Avoid absolute OS paths containing real usernames; use `C:\\Users\\user\\...` or `<USER_HOME>` instead.
- Run `scripts/audit.ps1` before committing to validate pointer hygiene and that no forbidden identifiers are present.

These principles form the lightweight contract we use when making trade-offs: if a feature conflicts with two or more principles above, we require a short reasoning thread in `reasoning-context.md` that documents the trade-offs and links to the changelog.

## Priorities

- [1] Keep context files up to date, organized, and focused. Refactor when needed
- [2] Identify, isolate, and refine project goals.
- [3] Figure out the next step to our current goal.

## Current Goals

- [1] Set up base project folder and environment [Phase 1]
- [2] Define modular plugin structure [Phase 1]
- [3] Create multiplayer plugin (prototype scaffolds created: `lere_core`, `lere_multiplayer`)
- [4] Validate Phase 1 datapack loads (datapack scaffold created at `datapacks/lere_guardian`)

## Long Term Goals

- [1] Implement multiplayer (ghosts, interactions)
- [2] Make Lere plugin (ai wolf follower, interactions)
- [3] Learn worldgen (biomes, structures)
- [4] Build narrative/quest plugin

## Design Constraints

- Must align with Minecraft's identity (block-based, chunk logic, multiplayer scaffolding).
- Performance and stability prioritized over experimental features.
## Pointer & Audit reference (lean summary)

The full pointer syntax guide, audit checklist, regex snippets, and ownership notes live in `chat_context/offloads/pointer-guidelines.md` (see `[knowledge-compartmentalization:offload-pointer-guide]` for the reference pointer). This file keeps the overview here, while the offload document stores the detailed conventions and commands.
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

## Context Hygiene Policies

**Purpose:** Prevent context bloat, keep philosophy evergreen, and ensure questions get triaged.

### Philosophy Refinement

The Guiding Philosophy and Core Design Principles should evolve with the project. Review triggers:

- **Quarterly review:** Every ~3 months, revisit philosophy during a session and ask:
  - Do these principles still reflect our actual decision-making?
  - Have we learned new constraints or priorities?
  - Are there principles we consistently ignore? (Remove or revise them)
  - Are there implicit principles we keep applying? (Document them)

- **Conflict trigger:** When a decision conflicts with 2+ principles, that's a signal to:
  - Create a reasoning thread to document the trade-off
  - Consider if the principles need refinement or if the decision is an exception

- **Refinement process:**
  1. Propose update in session-context.md with rationale
  2. If non-trivial, create reasoning thread `[#philosophy-update-YYYY-MM]` <!-- example -->
  3. Apply edit to general-chat-context.md
  4. Log in changelog with pointer to reasoning

### Open Questions Triage

Questions in `open-questions-context.md` should be actively managed, not left to rot.

**Triage cadence:** Monthly or at session start

**Status definitions:**
- `open` - Actively needs resolution; blocking or relevant to current work
- `deferred` - Intentionally postponed; not blocking; revisit in future phase
- `resolved` - Answered or no longer relevant; ready for pruning

**Triage checklist:**
1. Review each `open` question:
   - Still relevant? If answered elsewhere, mark `resolved`
   - Blocking current work? Keep `open`, consider prioritizing
   - Not relevant until Phase 2+? Mark `deferred` with note
2. Review `deferred` questions:
   - Now relevant? Promote to `open`
   - Superseded or obsolete? Mark `resolved`
3. Run `prune_questions.ps1` to archive resolved questions

**Priority tagging (optional):**
Add priority hints for open questions:
- `<!-- status: open; priority: high -->` - Blocking or critical path
- `<!-- status: open; priority: low -->` - Nice to resolve but not urgent

### Bloat Prevention

**File size limits:** Health check flags files over 500 lines or 50KB. When triggered:
- Archive old content (sessions, reasoning threads, changelog entries)
- Split large files if they cover multiple concerns
- Remove redundant or outdated content

**Archive hygiene:** Archives older than 90 days may be compacted or removed if:
- Content has been superseded by newer decisions
- No active pointers reference the archived content
- Storage/context budget is constrained

**Session scratchpad:** Prune after each session close:
- Move reusable insights to appropriate context file
- Archive lengthy sessions after 7 days
- Keep session-context.md focused on *current* work

### Health Check Prompts

The `health_check.ps1` script flags hygiene issues. Additionally, at each run it should prompt:

1. **Philosophy check:** "Any principles feel outdated or missing?"
2. **Questions triage:** "N open questions - review needed?"
3. **Bloat check:** "Files over threshold - archive or split?"

These prompts encourage human review rather than just automated fixes.

## Notes for Copilot

- Treat this as a Minecraft mod project.
- Use Fabric API conventions unless otherwise specified.
- Keep code modular and clean for future reuse.
- When in doubt, prioritize stability and performance.

## Project Folder Structure

Record of the top-level folders in this workspace and their purpose. Keep this updated when creating new major artifacts -- small changes should also add a short changelog anchor and, when needed, a brief reasoning thread.

```
Lere/                           # project root
+-- chat_context/               # persistent session & design memory
|   +-- archives/               # archived sessions, reasoning, questions
|   +-- changelog-context.md    # durable ledger of structural changes
|   +-- reasoning-context.md    # decision threads and trade-off analysis
|   +-- session-context.md      # session scratchpad and summaries
+-- datapacks/                  # datapacks for the project (data-layer)
|   +-- lere_guardian/          # Phase 1 datapack scaffold
+-- plugins/                    # server plugin source (Gradle projects)
|   +-- lere_core/              # prototype Paper plugin (zone commands)
|   +-- lere_multiplayer/       # multiplayer scaffold: AccessManager, visibility
+-- scripts/                    # PowerShell automation scripts
|   +-- audit.ps1               # pointer validation, manifest generation
|   +-- audit-data/             # manifests and logs (operational artifacts)
|   +-- lib/                    # shared script libraries
+-- docs/                       # optional design docs and exportable notes
+-- README.md
```

Quick pointers (what to update when adding new artifacts):
- When adding a new plugin or datapack, add a single-line changelog entry in `changelog-context.md` and a short reasoning stub in `reasoning-context.md` if trade-offs were involved.
- Add an example config path in the plugin's `src/main/resources` so devs know where to put zone coordinates and whitelist entries.
- Archives are stored in `chat_context/archives/`; audit manifests and logs are in `scripts/audit-data/`.

- Onboarding quick-start: see `chat_context/onboarding.md` for step-by-step PowerShell commands (audit, build, package, run server, run 2-player test).

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
      - Create a short session note (Session YYYY-MM-DD HH:MM) summarizing findings and link any created stubs with `[#thread]` and `[changelog-entry:...]` anchors. <!-- example -->

Canonical regex patterns (PowerShell examples):

```powershell
# Find reasoning-thread hashes
Get-ChildItem -Path "c:\Users\user\Dropbox\Dev\Lere\chat_context" -Recurse -Include *.md |
   Select-String -Pattern '\[#([^\]]+)\]' | Select-Object Path,LineNumber,Line

# Find changelog anchors
Get-ChildItem -Path "c:\Users\user\Dropbox\Dev\Lere\chat_context" -Recurse -Include *.md |
   Select-String -Pattern '\[changelog-entry:\d{4}-\d{2}-\d{2} \d{2}:\d{2}\]' | Select-Object Path,LineNumber,Line

# Find session markers
Get-ChildItem -Path "c:\Users\user\Dropbox\Dev\Lere\chat_context" -Recurse -Include *.md |
   Select-String -Pattern '\(Session \d{4}-\d{2}-\d{2} \d{2}:\d{2}\)' | Select-Object Path,LineNumber,Line
```

Cadence & ownership:

- Cadence: monthly and before major releases.  
- Owner: designated reviewer (project maintainer or person running the release); Copilot can run the audit on request and produce an orphan-report.


