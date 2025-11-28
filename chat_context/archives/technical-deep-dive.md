(Memory File)

# Technical Deep Dive

**Purpose:** Record the infrastructure, dependency, and resource assumptions that support the `technical-context.md` summary so engineers can make decisions with confidence.

---

## Hosting and environment guardrails

- **Primary target:** Digital Ocean or comparable VPS for affordability; document provider/region when deploying.
- **Fallback:** Transition to AWS/GCP only if the Phase 1 resource targets bump against reliability limits.
- **Runtime:** Match the chosen Minecraft server (Paper, Fabric, etc.) with the corresponding Java JDK/JRE and store the exact version/tag in `technical-context.md` when upgrades happen.
- **Toolchain:** Gradle (with Loom/Shadow) drives builds; include wrapper scripts in `plugins/lere_core` and `plugins/lere_multiplayer` for reproducibility.

## Dependency governance

- Follow the "Dependency Policy" checklist in `technical-context.md`:
  1. Every new dependency gets a reasoning stub in `reasoning-context.md` (link with the relevant reasoning thread, e.g., `[#phase-1-resource-scaffolding]`) and a changelog anchor `[changelog-entry:YYYY-MM-DD HH:MM]`.
  2. Record exact versions, license, and usage rationale in `technical-context.md` (Resource Inventory).
  3. Prefer built-in Java APIs or the targeted server modding API (Paper/Fabric) before reaching for third-party libs.
  4. Optional/polish dependencies must be opt-in, documented, and gated behind session or changelog references.

## Phase 1 resource scaffolding

- **Core plugins:** Multiplayer shared-zone management, quest tracking, worldgen/structure placement. Keep combined plugin size under 5MB and avoid runtime data dependencies.
- **Custom datapack:** Quest definitions, lore items, structures, recipes. Total datapack target: < 10MB.
- **Optional resource pack (Phase 2):** Keep custom textures/particles/sounds optional (Phase 2 add-on, < 30MB) and track them in the Resource Inventory checklist.
- **Distribution goal:** Entire Phase 1 package (plugins + datapack + launcher config) stays under 50MB so installs remain fast.

## Performance and benchmarks

- Track chunk loading, TPS, and memory usage metrics in `technical-context.md` as placeholders are replaced with real numbers.
- Run local servers (vanilla + plugin) with Gradle tasks before tagging releases; log the outcomes in session notes with pointer tags.

## Workflow reminders

- Document each major change in `technical-context.md` and link to the relevant reasoning thread/changelog entry to keep the audit trail complete.
- Refer back to this file whenever new infrastructure assumptions are proposed so the team sees the historical context.
