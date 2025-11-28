```markdown
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


```
