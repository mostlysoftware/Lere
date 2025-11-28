(Memory File)

# Session Cleanup Notes

**Purpose:** Capture the decisions that guide when sessions are closed, archived, and retried so the active `session-context.md` file stays lean.

---

## Closing criteria

- Every `(Session YYYY-MM-DD HH:MM)` block should include the metadata fields defined in `session-context.md` (Priority, Status, Last-updated, Archived).
- Close a session when the work is complete, blockers are resolved, or the session has been superseded by a priority-high journal entry.
- Update `Status` to `closed` and set `Last-updated` to the final timestamp before archiving; set `Archived: true` once the block is moved to `session-archive.md`.

## Archiving workflow

1. Confirm the session block has clear follow-ups and changelog anchors that point to the reasoning threads introduced during the session.
2. Move the entire block to `session-archive.md` (or a date-specific archive) in chronological order within this folder.
3. Replace the original block with a short summary stub that links to the archive using `[changelog-entry:YYYY-MM-DD HH:MM]` and the relevant reasoning thread (e.g., `[#pointer-syntax-standard]`).
4. Update `session-context.md` to reference the archive file (keep the most recent 3-5 sessions in place for quick recall; older ones live in the archive).

## Cleanup heuristics

- Periodically run `scripts/audit.ps1` (via `health_check.ps1`) and fix broken session markers or missing `Priority:` labels before archiving.
- Sessions older than 7 days with `Status: open` must either be closed or explicitly deferred with a `<!-- metadata ... -->` update.
- Use the `session-cleanup` template defined in `session-context.md` when migrating a block to an archive so the metadata stays machine-parseable.

## Follow-up references

- See `chat_context/session-context.md` for the templates mentioned above.
- Session archives live under `chat_context/archives/` (look for `session-archive*.md`).

