LereMultiplayer Plugin (scaffold)

This is the initial scaffold for the `lere_multiplayer` Paper plugin. It contains a minimal Gradle build and a main class so you can iterate quickly.

Contents
- `build.gradle`, `settings.gradle` — Gradle build configuration (adjust the paper-api version as needed)
- `src/main/java/dev/lere/multiplayer/LereMultiplayerPlugin.java` — main plugin class
- `src/main/resources/plugin.yml` — plugin descriptor
- `src/main/resources/config.yml` — default config (zones + whitelist placeholder)

Next steps
- Implement core commands and event listeners (zone management, visibility toggles, ghost behavior).
- Add access control (manual whitelist) when ready; automated monetization is deferred per project decision.

Build
- From the `plugins/lere_multiplayer` folder, run your Gradle wrapper or use an installed Gradle:
  ```powershell
  .\gradlew.bat build
  ```

Copy the generated JAR into your server `plugins/` folder and restart the server.

Example `config.yml` snippet (zones + whitelist)

```yaml
zones:
  hub:
    world: world
    x: 100
    y: 64
    z: 100
    yaw: 0
    pitch: 0

whitelist:
  enabled: true
  players:
    - "00000000-0000-0000-0000-000000000000" # replace with test UUID
```
