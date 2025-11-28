(Memory File)

# Plugin Context

**Purpose:** Plugin architecture, compatibility notes, dependencies, and integration patterns.

---

## Plugin List

- core plugin: 		handles scaffolding, gui, and logic; spine that connects plugins
- player plugin:	handles any changes to vanilla gameplay mechanics
- multiplayer plugin: 	player ghost system and online interactions
- lere plugin: 		npc wolf that follows the player with advanced interactions
- mob plugin: 		replace vanilla mobs with custom creatures
- npc plugin: 		replace vanilla npcs with custom npcs
- quest plugin:    handles game narrative and quest mechanics
- worldgen plugin: handles terrain and biome generation
- structure plugin: handles town and structure generation
- tools plugin: replace vanilla tools/weapons with custom ones
- magic plugin: handles magic system and mechanics
- sound plugin: potential long term goal, implement game ambience and music

- Notes: Prototype scaffolds created for Phase 1:
	- `plugins/lere_core` — initial Paper plugin prototype (zone commands, example config, and shared utilities for zone metadata)
	- `plugins/lere_multiplayer` — multiplayer scaffold that extends `lere_core` metadata, runs the `AccessManager` whitelist, provides `/access`+`/zone` commands, and enforces visibility via its `PlayerJoin` listener


## Plugin Relationship Map

* `lere_core` defines zone metadata, command hooks, and config helpers consumed by other plugins
* `lere_multiplayer` wires `lere_core` metadata into multiplayer visibility, ghosting, and whitelist enforcement (access + zone commands share the same config)
* quest plugin relates to world gen (story arcs tied to biomes)

