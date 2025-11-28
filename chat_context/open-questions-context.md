(Memory File)

# Open Questions Context

**Purpose:** Unified backlog of unresolved questions, grouped by source file.

---

## Format

Questions use inline metadata for pruning:
- `<!-- status: open -->` - Active question needing resolution
- `<!-- status: deferred -->` - Intentionally postponed; low priority

Example:
```markdown
- How to handle X? <!-- status: open -->
```

**Archived questions:**
 - Canonical reference (latest pruning batch): `archives/questions-archive-20251128-034213.md` (3 resolved questions).
 - Previous bundle retained for historical context: `archives/questions-archive-20251128-024538.md` (17 resolved questions).

---



## changelog-context.md




## gameplay-context.md

- Should quests adapt dynamically to player behavior? <!-- status: deferred --> Phase 2 - need base quest system first.
- What mechanics encourage cooperative discovery without breaking isolation? <!-- status: deferred --> Phase 2 - depends on multiplayer implementation.
- How to balance accessibility with challenge? <!-- status: deferred --> Phase 2 - need playtest data first.



## general-chat-context.md

- Should resource packs be bundled or optional? <!-- status: deferred --> Phase 2 consideration.


## open-questions-context.md




## plugin-context.md

- What testing framework ensures clean logs across SMP/dev? <!-- status: open; priority: low --> Nice to have, not blocking.


## reasoning-context.md



## session-context.md




## technical-context.md

- What's the minimum viable hosting setup for testing? <!-- status: resolved; priority: high --> Documented under `technical-context.md` “Minimum Viable Hosting Setup”; Phase 1 baseline complete.
- How to scale from dev to SMP without downtime? <!-- status: deferred --> Phase 2 - need working dev first.
- How to balance exploration with narrative pacing? <!-- status: deferred --> Phase 2 - design question, not blocking.
- How to integrate awe-inspiring terrain without breaking performance? <!-- status: deferred --> Phase 2 - worldgen iteration.
- Should custom textures be mandatory for immersion? <!-- status: deferred --> Phase 2.

