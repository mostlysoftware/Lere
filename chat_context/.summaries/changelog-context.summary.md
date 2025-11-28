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
- (2025-11-28, 03:22) Created `scripts/health_check.ps1` for comprehensive project health audits. Runs at project, scripts, plugins, or context scope. Checks include: file size/line thresholds, code duplication, function complexity, BOM/line-ending consistency, stale TODOs, plugin structure, context file hygiene, pointer integrity, and git status. Outputs to console, JSON, or markdown. See (Session 2025-11-28 03:00). [changelog-entry:2025-11-28 03:22]
- (2025-11-28, 03:19) Refactored audit infrastructure with shared libraries. Created `scripts/lib/Write-Atomically.ps1` (atomic file writes with retry), `scripts/lib/New-Manifest.ps1` (manifest generation with BOM/newline detection), `scripts/lib/FileCache.ps1` (cached file reading and unified pattern matching). Refactored `audit.ps1` from 591 to ~370 lines. Updated all pruner scripts (`prune_sessions.ps1`, `prune_reasoning.ps1`, `prune_changelog.ps1`, `prune_questions.ps1`) to use `Write-Atomically` with fallback. Fixed `Export-ModuleMember` error by adding module detection. See (Session 2025-11-28 03:00). [changelog-entry:2025-11-28 03:19]

*...preview truncated; full content available on demand.*


```
