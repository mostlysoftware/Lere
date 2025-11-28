<!-- summary: generated -->
<!-- source: C:\Users\Eris\Dropbox\Dev\Lere\chat_context\knowledge-compartmentalization.md -->
<!-- lines: 36 -->

(Memory File)

# Knowledge Compartmentalization Map

**Purpose:** Describe how to keep high-level context crisp while offloading deep details so the assistant can decide when to request extra knowledge.

---

## Strategy

1. **Summaries stay front and center:** Each context file keeps a concise overview of its topic. When detail grows beyond what the summary can absorb, it is moved into a dedicated offload file.
2. **Offload files live under `chat_context/archives/` or in-purpose subfiles:** They capture granular trade-offs, audit findings, or extended reasoning without cluttering the active context.
3. **Reference the offload path:** Summary sections link to the offload file using pointer tags so an LLM can decide, "Do I need that level of detail?" before requesting it.
4. **Document the trigger:** This map records why each topic was offloaded and when to fetch it (e.g., "If you need pointer syntax rules, request `chat_context/offloads/pointer-guidelines.md`." ).

## Offload index (examples)

| Topic | Summary location | Offload file | When to request |
|-------|------------------|--------------|-----------------|
| Audit checklist & pointer syntax | `chat_context/general-chat-context.md` (Section "Audit Checklist" / "Pointer Syntax") | `chat_context/offloads/pointer-guidelines.md` | When explaining pointer conventions or verifying health-check output references.
| Session cleanup heuristics | `chat_context/session-context.md` (active sessions) | `chat_context/archives/session-cleanup-notes.md` | When asked about archiving strategies or pruning rules beyond current sessions.
| Technical constraints & plugin scaffolding | `chat_context/technical-context.md` | `chat_context/archives/technical-deep-dive.md` | When the conversation requires low-level config, dependencies, or environment assumptions.
| Open questions backlog | `chat_context/open-questions-context.md` | `chat_context/archives/questions-archive-20251128-024538.md` | When reviewing deferred questions or examining how past answers evolved.
| Question prioritization playbook | `chat_context/open-questions-context.md` (Open Questions section) | `chat_context/archives/question-prioritization-2025-11.md` | When triaging new questions or deciding which backlog items to escalate.

## How to request offloaded knowledge

- Mention the desired topic and its offload file (or pointer tag) in your query: e.g., "Request pointer syntax details from `knowledge-compartmentalization.md` -> `pointer-guidelines.md`."
- If you only need a brief recap, cite the summary location and ask for a deeper dive if certain conditions apply.
- Treat this map as the directory of knowledge compartments; the assistant can stay brief unless the map specifically lets it escalate the detail level.

## Proactive Notes for Copilot

- Before overloading responses with deep detail, check this map and ask whether the user wants the offload file referenced.
- Use pointer tags (!) when referencing offloaded sections to keep future audits traceable (e.g., `[#pointer-guidelines] <!-- example -->`).
- Update this map whenever a new offload file is created or summaries shift shape.

