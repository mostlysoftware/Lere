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

- **Session → Reasoning:** Include hash-tag when a session decision references a reasoning thread.
  - Example: "Decision: Adopt modular plugin split. See [#plugin-architecture-tradeoff]." <!-- example -->

- **Reasoning → Changelog:** At the end of a reasoning thread, log the corresponding changelog entry.
  - Example: "Logged in [changelog-entry:2025-11-27 22:00]."

- **Changelog → Session/Reasoning:** Each durable entry should point back to its origin.
  - Example: "(2025-11-27, 22:00) Codified edit cycle convention. See (Session 2025-11-27 21:45) and [#edit-cycle-convention]."

### Benefits

- Scannability: Uniform tags make references grep-able and human-readable.
- Resilience: Even mid-crash, manual checkpointing with tags keeps threads traceable.
- Archiving: Tags allow pruning or consolidating reasoning threads without losing linkage.

## Audit Checklist (lightweight)

Purpose: a short, repeatable checklist to keep pointer/linkage hygiene and changelog/session sync healthy. Run this before major releases or monthly.

1. **Gather pointer evidence**
   - Search for reasoning-thread hashes: `[#... ]` across `chat_context` and list unique tags.
   - Search for changelog anchors: `[changelog-entry:YYYY-MM-DD HH:MM]` and session markers `(Session YYYY-MM-DD HH:MM)`.

2. **Orphan check**
   - For each reasoning-thread hash found, confirm a corresponding stub exists in `reasoning-context.md`.
   - For each changelog anchor found, confirm the referenced changelog line exists and links to a session or reasoning thread.

3. **Formatting checks**
   - Ensure pointer tags match the canonical regex patterns documented below.
   - Confirm hyphen bullet style (`-`) is used across the file set.

4. **Actions on orphans**
   - If a hash is orphaned and intended to be real: create a short stub in `reasoning-context.md` and add a changelog anchor to the relevant changelog entry.
   - If a hash is an example/demo, mark it with `<!-- example -->` on the same line to avoid future false positives.

5. **Record audit results**
   - Create a short session note `(Session YYYY-MM-DD HH:MM)` summarizing findings and link any created stubs with `[#thread]` and `[changelog-entry:...]` anchors. <!-- example -->

## Canonical regex patterns (PowerShell examples)

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

## Cadence & ownership

- Cadence: monthly and before major releases.
- Owner: designated reviewer (project maintainer or release runner); Copilot can run the audit on request and produce an orphan-report.

