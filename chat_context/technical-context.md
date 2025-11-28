(Memory File)

# Technical Context

**Purpose:** Environment setup, hosting strategies, migration notes, and performance benchmarks. Keeps infrastructure separate from design.

---

## Multiplayer framework: architecture notes

Decision scope: choose an approach for multiplayer isolation (shards vs in-plugin zones), compatibility constraints, and a lightweight API to let future plugins (worldgen, quests, etc.) cooperate without tight coupling.

Summary recommendation
- Start with an in-plugin, single-server zone system implemented in `plugins/lere_multiplayer` that provides lightweight primitives (zone definitions, teleport, entry/exit events, access checks, ghost/visibility toggle). This avoids the complexity and operational overhead of a sharding system while meeting the project's stated goals for a small, stable Phase 1 deliverable.

Why not shards (yet)
- Sharding (multiple server instances with proxy/routing) adds operational complexity: cross-server player routing, persistent player state, proxy coordination (Bungee/Velocity), additional infra for synchronization, and harder local testing. For this project phase the extra failure modes and maintenance burden are disproportionate to the benefits.

When shards become appropriate
- If the project later requires horizontal scaling (many concurrent players, geographically distributed instances, or hard isolation across worlds that cannot coexist on one server), design an adapter layer in the plugin that can be extended to use a proxy-based shard coordinator or a publish-subscribe backend (Redis, Kafka) for cross-instance events.

Design constraints & compatibility
- Must run standalone on a single PaperMC server without external services. Avoid optional dependencies that prevent vanilla Paper usage.
- Must cooperate with other plugins: expose a small, stable API (Java events and plugin messaging) so `plugins/lere_worldgen`, `plugins/lere_quests`, and future plugins can listen for zone entry/exit, request teleports, or query zone metadata.
- Respect custom worlds: zone definitions must include world names (config-driven) and avoid assuming the 'overworld' only. When world is not loaded, provide graceful failure or auto-load behavior if possible (documented behavior).
- Keep the core minimal and robust: minimal background threads, non-blocking IO for persistence, atomic config writes via existing `Write-Atomically` helper.

API and event contract (tiny surface area)
- ZoneEnteredEvent(zoneId, player, previousZone)
- ZoneLeftEvent(zoneId, player, newZone)
- ZoneManager API (getZone(id), listZones(), createZone(...), removeZone(...), teleportToZone(player, id))
- AccessManager API (isAllowed(UUID), add/remove/list)
- Teleport API should provide a callback or boolean result indicating success/failure and reason (unsafe, world-missing, cooldown)

Operational & testing priorities
- Make default config simple: a hub zone that always exists; document how to add custom worlds.
- Teleport safety: prefer in-server safe-spot heuristics over remote checks; provide a configurable safety fallback.
- Start with per-player in-memory state for current zone membership; persist authoritative definitions (zones + whitelist) to plugin config.
- Provide a manual migration path if sharding is adopted later: an adapter layer that maps local zone operations to remote calls.

Principle: graceful optional dependencies
- Plugins must not hard-fail when other Lere plugins are missing. Each plugin should check for the presence of cooperating plugins at runtime and only enable optional integration code when the counterpart is available. Missing peers should result in disabled integration paths and clear log messages, not crashes. This keeps each plugin runnable standalone on a vanilla PaperMC server while enabling richer cooperation when multiple Lere plugins are installed.

Acceptance criteria for Phase 1
- Plugin runs on a vanilla PaperMC server with no extra services and exposes `/zone join|leave|list`.
- Zone entry/exit events fire and other plugins can register listeners.
- Ghost mode toggle works as prototype (visibility to non-zone players suppressed).
- Config persists dynamic changes to `config.yml` using atomic writes.

Next steps
1. Implement `ZoneManager` core + `/zone list/join/leave` (this is in the todo list as the first development item).  
2. Implement config validation and hub default zone.  
3. Prototype ghost mode and the AccessManager integration.  
4. Document the API contract in `chat_context/technical-context.md` and add a short developer guide to `plugins/lere_multiplayer/README.md`.


---

## Hosting Strategy

- Likely digital ocean for affordability, with possibility of transition to AWS or similar if needs evolve.

### Minimum Viable Hosting Setup

This is the resolved answer to the open question about the minimum viable hosting setup for testing Phase 1.

- **Baseline hardware**: 2 vCPUs, 4–8 GB RAM (start at 4 GB; upgrade if Paper server consistently hits >3 GB heap), 60 GB SSD, and 1 Gbps net. Use a low-cost provider (DigitalOcean Basic/General Purpose, Hetzner CX31, or Azure B1ms) so the team can spin spin up/down quickly.
- **Operating system**: Ubuntu 24.04 LTS (or Windows Server 2022 if Windows-specific tooling is required). Keep the host minimal (no GUI) and apply unattended upgrades from day 1.
- **Runtime stack**:
  1. Install Java 21 LTS (Temurin or Microsoft build) via package manager or SDKMAN; pin the version in `technical-context` resource inventory once chosen.
  2. Download the latest Paper 1.20.4+ jar and place it under `/srv/lere/server.jar` (or similar). Adopt the vanilla `eula.txt`-driven first run to generate baseline configs.
  3. Configure a `systemd` service (or scheduled PowerShell task) that launches the server with `-Xms1G -Xmx3G` and auto-restarts on failure, logging to `/var/log/lere-server.log`.
  4. Mount a dedicated data disk for world and plugin files; snapshot regularly (daily) and prune old snapshots in `scripts/snapshot-prune.ps1`.
- **Networking/security**: Open only the Minecraft port (25565) and SSH (22/whatever) through firewall; add fail2ban or similar. Use a static IP or DNS entry documented in `changelog-context`.
- **Local testing alternative**: Mirror the above by running the same Paper jar on a local dev box (Linux/WSL) with 6 GB RAM and supporting `./gradlew runServer`. This ensures parity before pushing changes to the hosted environment.



## Migration Notes

- Expand later with notes on containerization and portability



## Performance Benchmarks:

- Expand later when needed, for logging benchmarks like tps, ram usage, player cap

## Resource Context

- For datapacks, resource packs, and external assets. Tracks whatÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢s essential vs. optional polish.
- Right now the focus is core functionality in an isolated environment, so we are going to aim for an ideal goal of no outside dependencies that aren't strictly necessary. Each plugin I distribute should "just work" out of the box

## Resource Inventory

- [essential] Shards (Minecraft development). not sure if this counts as an asset but i'll put it here for now 

## Dependency Policy

### Philosophy

- Goal: prefer zero external dependencies unless they are essential for development or runtime.
- If a dependency is introduced, it must meet the criteria below and be recorded with a short reasoning thread in `reasoning-context.md` and a changelog anchor in `changelog-context.md`.

### Criteria for "Essential"

A dependency is "essential" if it is required to build or run the mod in a way that cannot be reasonably implemented in-project, including:

- Target server API/runtime (e.g., the chosen server modding API: Paper, Spigot, Fabric, or equivalent) required to run the plugin/mod for the chosen platform.
- A matching Java JDK/runtime for the targeted Minecraft version (document exact vendor and version numbers in the changelog).
- Build tooling and pipelines that are required to produce artifacts: Gradle/Maven (with Loom/Shadow as needed), CI scripts used to build release artifacts.
- Version control tooling (Git) and local test server jars needed to reproduce a development environment.
- Small, widely-adopted libraries that remove impractical duplication and have stable maintenance and permissive licenses (e.g., logging utilities, commons libraries) ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â justify in a reasoning thread.

### Criteria for "Optional / Polish"

These are allowed but should be opt-in and avoid adding runtime weight or external availability requirements:

- Resource packs, texture packs, or large multimedia assets (should be optional downloads, not mandatory at startup).
- Cloud services (analytics, remote configuration, telemetry) ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â require explicit opt-in and privacy considerations.
- Large third-party plugins or mods that are only convenience features (PlaceholderAPI, Citizens-style NPC libraries) ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â keep as optional integrations.
- Native binaries, external databases, or services that introduce operational complexity (e.g., Redis, external AI APIs) ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â prefer local or server-side alternatives where possible.

### Process for Adding a Dependency

1. Open a short reasoning thread in `reasoning-context.md` describing why the dependency is needed, trade-offs, and failure modes. Link to it with `[#reasoning-thread-title]`. <!-- example -->
  (example: `[#reasoning-thread-title]` <!-- example -->)
2. Create a changelog entry that references the reasoning thread with `[changelog-entry:YYYY-MM-DD HH:MM]`.
3. Document the exact version, license, and minimal configuration in `technical-context.md` under Resource Inventory.
4. Prefer alternatives that keep the codebase self-contained; if no alternative exists, add the dependency as essential.

### Examples (non-exhaustive)

- Essential: Java 17/21 JDK matching the target MC version; Gradle + Loom for Fabric mod development; Paper server jar for Paper plugins.
- Optional: high-fidelity resource packs, optional community mods for QoL, analytics services, remote telemetry.

## Phase 1 Resource Scaffolding

**Decision:** See reasoning thread [#phase-1-resource-scaffolding] for trade-off analysis.

**Phase 1 goal:** Minimal essential footprint; art/polish deferred to Phase 2.

### Phase 1 Resource Inventory

- [essential] **Core plugins** (bundled with mod):
  - Multiplayer plugin (ghost system, shared zones, player visibility)
  - Quest plugin (quest tracking, biome hints, lore books)
  - Worldgen plugin (biome distribution, structure placement, custom terrain)
  - Total plugin size target: < 5MB

- [essential] **Custom datapack** (bundled with mod):
  - Quest data (quest definitions, tracking, rewards)
  - Lore items (lore books with narrative snippets)
  - Custom structures (temples, quest hubs, landmark locations)
  - Custom crafting recipes (if any quest-specific items)
  - Total datapack size target: < 10MB

- [optional] **Resource pack** (Phase 2):
  - Custom textures (deferred; use vanilla textures in Phase 1)
  - Particle effects (deferred; use vanilla particles)
  - Sound packs (deferred; use vanilla sounds)
  - Total resource pack size (Phase 2 estimate): < 30MB

### Phase 1 Install Size Target

- Total mod distribution (Phase 1): < 50MB (plugins + datapack + launcher config)
- Deferred to Phase 2: custom resource pack (Phase 2 add-on, optional)

### Phase 1 Installation Checklist

- [ ] Verify all plugins have zero external JAR dependencies (Java stdlib only, or listed below)
- [ ] Confirm datapack structure is valid (namespace, recipes, loot tables, structures)
- [ ] Test "just works" install: players unzip and run without additional setup
- [ ] Document exact file list and size for distribution
- [ ] Package mods + datapack into single distribution archive
- [ ] Test on clean Minecraft server environment before release

### Allowed Libraries for Phase 1 Plugins

- Java stdlib (java.lang, java.util, java.io, etc.)
- Bukkit/Paper API (for Paper plugins)
- Fabric API (for Fabric mods)
- [if justified] Small, stable, license-compliant libraries: SLF4J (logging), GSON (JSON parsing), Commons Lang (utilities) ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â require reasoning thread with justification


# Worldgen Context

- Biome themes and distribution logic
- Structure placement rules (temples, ruins, quest hubs)
- Terrain shaping philosophy (layered, modular, awe-inspiring)
- Integration with vanilla mechanics (ores, caves, villages)
- Performance constraints and chunk loading strategy

*- Related Contexts:**
- narrative-context.md (story arcs tied to biomes)
- plugin-context.md (structure placement logic)

*- Performance Benchmarks:**

- chunk loading targets: not decided
- tps thresholds: not decided
 
---

## Datapack Scaffolding (Phase 1)

Minimal starter plan to validate loading and provide placeholders for quests and lore.

Checklist:
- [ ] Create `pack.mcmeta` with pack format targeting current MC version.
- [ ] Create namespace folder `data/lere_guardian/` with subfolders: `advancements/`, `loot_tables/`, `recipes/`, `structures/`, `tags/biomes/`.
- [ ] Add placeholder advancement `advancements/quest_intro.json` referencing a lore book.
- [ ] Add placeholder structure entry `structures/quest_hub.nbt` (stub to be replaced later).
- [ ] Add minimal biome tag in `tags/biomes/shared_zones.json` for concept scaffolding.
- [ ] Validate on a clean server; record load success in session close.

Notes:
- Keep JSON small and syntactically valid; prefer vanilla references for Phase 1.
- Link any substantive additions to `[changelog-entry:YYYY-MM-DD HH:MM]` and a short reasoning stub if needed.


