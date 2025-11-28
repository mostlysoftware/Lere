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

### Kickoff Template

```markdown
## (Session YYYY-MM-DD HH:MM)
<!-- metadata
Priority: low
Status: open
Last-updated: YYYY-MM-DD HH:MM
Archived: false
-->

**Attendees:** [names]
**Goal(s):** [short goal list]
**Files in scope:** [list files]
**Quick context:** [1-2 sentence context]
**Expected outputs:** [decisions, PRs, tickets]
```

### Close Template

```markdown
## (Session YYYY-MM-DD HH:MM)
<!-- metadata
Priority: high
Status: closed
Last-updated: YYYY-MM-DD HH:MM
Archived: false

*...preview truncated; full content available on demand.*

