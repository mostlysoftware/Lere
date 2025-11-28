# chat_context README

This folder holds the project's in-repo assistant memory and governance artifacts.

What is this "prosthetic memory"?
---------------------------------

This repository contains a small, curated "prosthetic memory" for the project: an on-disk, human-readable set of summaries, decisions, and operational notes that help both contributors and LLM-based tools act consistently. Its goals are:

- Make important context explicit and easy to find (design decisions, open questions, governance). 
- Reduce noisy or duplicative content passed into LLM prompts by centralizing summaries in `./.summaries/` and offloading deep documents to `./archives/` or `./offloads/`.
- Provide reproducible heuristics and scripts (health checks, generators, offloads) so the memory stays small, fresh, and reviewable.
- Preserve privacy and auditability: sensitive material can be offloaded/archived and is not required for routine assistant reasoning.

Use this memory when you want the assistant or a collaborator to make decisions aligned with past reasoning. When editing, prefer updating summaries and the canonical `*-context.md` files rather than scattering ad-hoc notes across the repo.

## Quick Links

- Centralized summaries: `./.summaries/`  
	- One-shot consolidated: `./.summaries/CONSOLIDATED_SUMMARIES-20251128.md`
- Offloads (detailed guidance): `./offloads/pointer-guidelines.md`
- Archives (supporting docs):  
	- `./archives/ATTACHMENTS.md` (file batching guide)  
	- `./archives/knowledge-compartmentalization.md` (map of summaries vs. offloads)  
	- `./archives/technical-deep-dive.md`  
	- Latest session snapshot: `./archives/session-close-20251128-0950.md`
- Privacy policy: `./PRIVACY.md`

PowerShell shell integration (optional):

```powershell
# Install once
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install_shell_integration.ps1

# Handy commands
hc -Scope context -Report console        # health check
offload -Push                            # offload optional files and push
purgesummaries                           # purge stray top-level *.summary.md
ctxsum -Force                            # regenerate centralized summaries
```

## Context File Format

All `*-context.md` files follow a standard header:

```markdown
(Memory File)

# [Title] Context

**Purpose:** One-line description.

---

[Content sections...]
```

## Core Files

| File | Purpose |
|------|---------|
| `general-chat-context.md` | Project philosophy and workflow notes |
| `reasoning-context.md` | Long-form reasoning threads (one per major decision) |
| `changelog-context.md` | Durable ledger of structural changes |
| `session-context.md` | Session scratchpad and summaries |
| `technical-context.md` | Technical constraints, Phase 1 inventory |
| `plugin-context.md` | Plugin architecture and dependencies |
| `gameplay-context.md` | Gameplay mechanics and narrative design |
| `open-questions-context.md` | Unified backlog of open questions |

## Audit & Example Marker Convention

When showing example pointer usage in documentation (for humans), mark the example line with:

```markdown
<!-- example -->
```

This tells `scripts/audit.ps1` to ignore that line so examples don't trigger false-positive missing-pointer findings.

Example usages include template lines like `[#reasoning-thread]` <!-- example --> or `[#thread]` <!-- example --> inside templates or documentation.

## Running the Audit

From PowerShell (Windows), run the audit script with ExecutionPolicy bypass:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "scripts/audit.ps1"
```

On CI (GitHub Actions) the workflow `/.github/workflows/audit.yml` runs the same check automatically.

## Pruning Scripts

| Script | Purpose |
|--------|---------|
| `scripts/prune_sessions.ps1` | Archive old session blocks |
| `scripts/prune_reasoning.ps1` | Archive resolved reasoning threads |
| `scripts/prune_changelog.ps1` | Archive old changelog entries |
| `scripts/prune_questions.ps1` | Archive resolved questions |

If you need a different convention or want the audit to ignore additional markers, update `scripts/audit.ps1` accordingly and document the change here.

## Knowledge compartmentalization guidance

- Consult `./archives/knowledge-compartmentalization.md` to see the high-level topics that stay in the active contexts and the dedicated offload files (like `offloads/pointer-guidelines.md`) that hold the detailed versions.
- When responding, prioritize the summary in the main context files. If an LLM or contributor requires extra depth, reference the relevant offload file and ask for it explicitly instead of absorbing every detail by default.

