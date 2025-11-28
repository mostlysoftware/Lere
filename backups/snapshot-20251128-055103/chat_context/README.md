# chat_context README

This folder holds the project's in-repo assistant memory and governance artifacts.

## Quick Links

- **`quickstart.md`** - LLM cheatsheet for fast onboarding
- **`decisions.md`** - Distilled decision log (key choices at a glance)
- **`attachments.md`** - File batching guide for LLMs with file count limits
- **`onboarding.md`** - Contributor quick-start guide
- **`privacy.md`** - Privacy & anonymization policy

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
