# Open Questions Archive

Archived on 2025-11-28 02:45

These questions have been resolved and moved from open-questions-context.md.

---

## Format

- `<!-- status: resolved -->` - Answered/addressed; eligible for archiving
- Should we use Y? <!-- status: resolved --> Decided: Yes, see [#reasoning-thread] <!-- example -->

## changelog-context.md

- How to keep changelog context concise but retain details that are "need to know" to track progress? <!-- status: resolved --> Implemented pruner with age-based archiving.

## gameplay-context.md

- How to preserve narrative integrity in multiplayer? <!-- status: resolved --> See [#multiplayer-isolation-mechanics].
- Should narrative arcs be tied to biome progression? <!-- status: resolved --> See [#quest-plugin-architecture].
- How to handle player drop-in/drop-out without breaking story flow? <!-- status: resolved --> See [#multiplayer-isolation-mechanics].
- How to balance solo narrative with shared SMP? <!-- status: resolved --> Hybrid isolation model chosen.

## general-chat-context.md

- How to balance narrative isolation with multiplayer accessibility? <!-- status: resolved --> Hybrid model.
- Which plugins/datapacks are essential for scaffolding vs. optional polish? <!-- status: resolved --> See technical-context.md dependency policy.

## open-questions-context.md

- Best way to optimize open questions for human and AI readability? <!-- status: resolved --> Added inline status metadata.

## plugin-context.md

- What plugin architecture best supports player isolation? <!-- status: resolved --> See [#plugin-architecture-tradeoff].
- How to modularize plugins for optional installs? <!-- status: resolved --> Modular core + optional modules.

## session-context.md

- Best way to handle or format the session file? <!-- status: resolved --> Unified metadata format implemented.
- Is pasting a whole snippet necessary? <!-- status: resolved --> No, use templates.
- Is this file redundant? <!-- status: resolved --> No, serves as scratchpad distinct from changelog.

## technical-context.md

- Should biomes reflect story arcs or gameplay zones? <!-- status: resolved --> See [#quest-plugin-architecture].
- How to balance lightweight installs vs full conversion? <!-- status: resolved --> See [#phase-1-resource-scaffolding].


