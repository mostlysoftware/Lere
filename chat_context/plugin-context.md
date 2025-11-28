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
- quest plugin: 	handles game narrative and quest mechanics
- worldgen plugin: 	handles terrain and biome generation
- structure plugin:	handles town and structure generation
- tools plugin:		replace vanilla tools/weapons with custom ones
- magic plugin:		handles magic system and mechanics
- sound plugin:		potential long term goal, implement game ambience and music

-- Notes: Prototype scaffolds created for Phase 1:
	- `plugins/lere_core` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â initial Paper plugin prototype (zone commands, example config)
	- `plugins/lere_multiplayer` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â multiplayer scaffold with `AccessManager`, admin `/access` command, `/zone` command, and a `PlayerJoin` listener enforcing the manual whitelist MVP



Plugin Relationship Map

* quest plugin relates to world gen (story arcs tied to biomes)
