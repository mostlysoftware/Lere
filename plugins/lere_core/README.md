LereCore Plugin (prototype)

This is a minimal Paper plugin scaffold for the Lere's Guardian multiplayer module.

Contents:
- `build.gradle`, `settings.gradle` — simple Gradle setup (adjust paper-api version as needed)
- `src/main/java/dev/lere/core/LereCorePlugin.java` — plugin main class
- `src/main/java/dev/lere/core/commands/ZoneCommand.java` — handles `/zone join <name>` and `/zone leave`
- `src/main/resources/plugin.yml` — plugin descriptor
- `src/main/resources/config.yml` — sample zones and whitelist config

Build:
- Use Gradle to build the plugin JAR. Example (from plugin directory):

  gradlew build

- Copy the generated JAR to your server `plugins/` folder and restart the server.

Notes & next steps:
- Visibility toggles, ghost spawning, and summon/invade flows are stubbed as TODOs.
- Add persistence and access control (whitelist/Patreon integration) next.
- Adjust `paper-api` version in `build.gradle` to match target server Minecraft version.
