package dev.lere.core;

import dev.lere.core.commands.ZoneCommand;
import org.bukkit.plugin.java.JavaPlugin;

public final class LereCorePlugin extends JavaPlugin {

    private static LereCorePlugin instance;

    @Override
    public void onEnable() {
        instance = this;
        saveDefaultConfig();

        // Register commands
        getCommand("zone").setExecutor(new ZoneCommand(this));

        getLogger().info("LereCorePlugin enabled.");
    }

    @Override
    public void onDisable() {
        getLogger().info("LereCorePlugin disabled.");
    }

    public static LereCorePlugin getInstance() {
        return instance;
    }
}
