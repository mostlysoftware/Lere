<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\offloads\pointer-guidelines.md -->
<!-- lines: 89 -->

(Memory File)

# Pointer & Audit Guidelines (Offload Details)

**Purpose:** Store the canonical pointer syntax, audit checklist, and related notes without crowding the primary `general-chat-context.md` file.

---

## Pointer Syntax Standard (full detail)

**Purpose:** Keep references between files uniform, scannable, and resilient to crashes or context loss.

### Pointer Types

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

### Linking Rules

- **Session â†’ Reasoning:** Include hash-tag when a session decision references a reasoning thread.
  - Example: "Decision: Adopt modular plugin split. See [#plugin-architecture-tradeoff]." <!-- example -->

- **Reasoning â†’ Changelog:** At the end of a reasoning thread, log the corresponding changelog entry.
  - Example: "Logged in [changelog-entry:2025-11-27 22:00]."

- **Changelog â†’ Session/Reasoning:** Each durable entry should point back to its origin.
  - Example: "(2025-11-27, 22:00) Codified edit cycle convention. See (Session 2025-11-27 21:45) and [#edit-cycle-convention]."


*...preview truncated; full content available on demand.*

