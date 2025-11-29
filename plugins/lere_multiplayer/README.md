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

Local developer helper
----------------------

If you prefer to run builds without installing Gradle globally, use the repo helper script from the repository root. It will detect a Gradle wrapper or download a local Gradle distribution into `./.dev/gradle` and invoke it (requires a JDK to be available).

From the repo root (PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\dev_setup.ps1 -RunBuild
```

If you do not have a JDK installed, the script will show recommended install commands and will not proceed until a JDK is available.

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

Config validation
-----------------

On plugin enable the configured zones are validated. Zones that reference a non-existent world or contain invalid coordinates will be skipped and a warning logged to the server console. If no valid zones are present a default `hub` zone will be created and persisted to the plugin config. Y coordinates outside the world's bounds are clamped to a safe value to avoid unsafe teleports.

This makes it safer to edit `config.yml` by hand and prevents the plugin from throwing errors on startup when a bad zone entry exists.
