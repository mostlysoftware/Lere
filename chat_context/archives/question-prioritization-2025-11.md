(Memory File)

# Question Prioritization (2025-11)

**Purpose:** Capture the rules used to triage the open questions backlog so the team consistently escalates the most pressing unresolved items.

---

## Triage criteria

1. **Status tags:** Use `<!-- status: open -->` for blockers that block progress; `<!-- status: deferred -->` for ideas that are nice-to-have. Every question should keep that tag on the same line.
2. **Priority flag:** Annotate `priority: high` or `priority: low` when the difference affects session planning (default to `normal` if unspecified).
3. **Dependencies:** Tag questions that need specific context files (e.g., `technical-context.md`, `plugin-context.md`) so the assistant can route them to the right owner.
4. **Changelog / session linkage:** When a question motivates a decision, close it with a changelog entry `[changelog-entry:YYYY-MM-DD HH:MM]` and link to the session or reasoning thread that answered it.

## Maintenance workflow

- Weekly (or before big pushes), run `scripts/audit.ps1` or `health_check.ps1` to surface any open questions with missing metadata or duplicate content.
- Once a question is marked `resolved`, archive it in a dated archive (see `questions-archive-20251128-024538.md` and `questions-archive-20251128-034213.md` in this folder) so the backlog stays focused.

## Escalation guidance

- Prioritize high-impact blockers first (assign `priority: high` in the question line).
- Defer design exploration until Phase 2 by setting `<!-- status: deferred -->` and referencing why it was postponed.
- Use this playbook to decide whether to route a question to a reasoning thread, leave it in open questions, or defer it to a future session.

## Follow-up pointers

- Refer to `open-questions-context.md` for the live backlog.
- Check the archives under `chat_context/archives/` to see resolved questions sorted by date.
- Update this playbook as new triage heuristics emerge.

