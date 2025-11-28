(Memory File)

# Reasoning Context

**Purpose:** Long-form reasoning threads for design decisions and trade-offs. One thread per major decision; reference from session-context.md when active.

---

## Thread Format

Use this compact table format for new threads:

```
## Reasoning Thread: [thread-name]
<!-- status: open | resolved -->

| Field | Value |
|-------|-------|
| **Question** | What problem are we solving? |
| **Options** | A) Option 1  B) Option 2  C) Option 3 |
| **Decision** | What we chose and why |
| **Next** | Changelog entry, implementation steps |

### Notes (optional)
- Context, constraints, follow-ups
```

---

## Active Threads

---

## Reasoning Thread: [multiplayer-shared-zone-mvp]
<!-- status: open -->

| Field | Value |
|-------|-------|
| **Question** | What is the minimal shared zone implementation for Phase 1? |
| **Options** | A) Command-driven B) GUI/menu toggle |
| **Decision** | A) Command-driven - small footprint, testable with 2 players |
| **Next** | [changelog-entry:2025-11-27 23:50] |

### Notes
- Depends on: [#multiplayer-isolation-mechanics]
- MVP criteria: join/leave without quest state mutation
- Phase 2: Add GUI toggle

### Checklist
- [ ] Zone config in config.yml
- [ ] /zone join and /zone leave commands
- [ ] Visibility filtering via Player#hidePlayer/showPlayer
- [ ] AccessManager with /access admin command
- [ ] Quest isolation (no state mutation on zone toggle)
- [ ] Dev test: 2-player join/see/leave cycle

---

## Reasoning Thread: [phase-1-resource-scaffolding]
<!-- status: open -->

| Field | Value |
|-------|-------|
| **Question** | Which datapacks/resource packs are essential for Phase 1? |
| **Options** | A) Vanilla-only  B) Minimal datapack  C) Full custom resource pack |
| **Decision** | B) Minimal datapack - quest tracking, lore, structures only |
| **Next** | [changelog-entry:2025-11-27 23:15] |

### Notes
- Target: < 50MB total Phase 1 package
- Defer textures/sounds to Phase 2

---

## Reasoning Thread: [quest-plugin-architecture]
<!-- status: open -->

| Field | Value |
|-------|-------|
| **Question** | Should quests be biome-locked or free-form? |
| **Options** | A) Biome-locked  B) Abstract/free-form  C) Hybrid (biome hints) |
| **Decision** | C) Hybrid - biome suggestions guide discovery, no hard locks |
| **Next** | [changelog-entry:2025-11-27 23:15] |

### Notes
- Maximizes replayability (different quest order per run)
- Quest log includes biome hint but allows any-order pursuit

---

## Reasoning Thread: [multiplayer-isolation-mechanics]
<!-- status: open -->

| Field | Value |
|-------|-------|
| **Question** | How to prototype multiplayer ghosts while preserving narrative isolation? |
| **Options** | A) Full instancing  B) Visibility filtering  C) Hybrid |
| **Decision** | C) Hybrid - private instances for story, shared zones for optional co-op |
| **Next** | [changelog-entry:2025-11-27 23:15] |

### Notes
- Balances Narrative Integrity with Replayability
- Low-latency by separating story from multiplayer concerns

---

## Reasoning Thread: [plugin-architecture-tradeoff]
<!-- status: open -->

| Field | Value |
|-------|-------|
| **Question** | What plugin architecture for isolation, instancing, and modularity? |
| **Options** | A) Monolithic core  B) Strict modular plugins |
| **Decision** | Minimal core + optional modules for flexibility |
| **Next** | Prototype and revisit |

### Notes
- Balances performance and modularity for community distribution

---

## Archived Threads

See archives/reasoning-archive-*.md for resolved threads:
- [#pointer-syntax-standard] - resolved
- [#context-consolidation] - resolved
- [#context-restoration-test] - resolved
- [#edit-cycle-convention] - resolved
- [#governance-framework] - resolved

