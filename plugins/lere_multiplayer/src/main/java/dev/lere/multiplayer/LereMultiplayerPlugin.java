package dev.lere.multiplayer;

import org.bukkit.plugin.java.JavaPlugin;
import dev.lere.multiplayer.access.AccessManager;
import dev.lere.multiplayer.commands.ZoneCommand;
import dev.lere.multiplayer.commands.AccessCommand;
import dev.lere.multiplayer.listeners.JoinListener;

public class LereMultiplayerPlugin extends JavaPlugin {

    private AccessManager accessManager;
    private dev.lere.multiplayer.zone.ZoneManager zoneManager;

    @Override
    public void onEnable() {
        getLogger().info("LereMultiplayer enabled");
        saveDefaultConfig();

    this.accessManager = new AccessManager(this);
    this.accessManager.load();

    // Zone manager handles zone definitions and teleports
    this.zoneManager = new dev.lere.multiplayer.zone.ZoneManager(this);
    this.zoneManager.loadFromConfig();

        // Register commands
        this.getCommand("zone").setExecutor(new ZoneCommand(this));
        this.getCommand("access").setExecutor(new AccessCommand(this));

        // Register listeners
        getServer().getPluginManager().registerEvents(new JoinListener(this), this);
    }

    @Override
    public void onDisable() {
        getLogger().info("LereMultiplayer disabled");
        if (this.accessManager != null) this.accessManager.save();
    }

    public AccessManager getAccessManager() { return this.accessManager; }
    public dev.lere.multiplayer.zone.ZoneManager getZoneManager() { return this.zoneManager; }
}
