package dev.lere.multiplayer.access;

import dev.lere.multiplayer.LereMultiplayerPlugin;
import org.bukkit.configuration.file.FileConfiguration;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

public class AccessManager {
    private final LereMultiplayerPlugin plugin;
    private final Set<UUID> whitelist = new HashSet<>();

    public AccessManager(LereMultiplayerPlugin plugin) {
        this.plugin = plugin;
    }

    public void load() {
        FileConfiguration cfg = plugin.getConfig();
        if (!cfg.getBoolean("whitelist.enabled", false)) return;
        List<String> players = cfg.getStringList("whitelist.players");
        whitelist.clear();
        for (String s : players) {
            try {
                whitelist.add(UUID.fromString(s.trim()));
            } catch (Exception e) {
                plugin.getLogger().warning("Invalid UUID in whitelist: " + s);
            }
        }
        plugin.getLogger().info("Loaded whitelist: " + whitelist.size() + " entries");
    }

    public void save() {
        FileConfiguration cfg = plugin.getConfig();
        // persist list of UUID strings
        cfg.set("whitelist.players", whitelist.stream().map(UUID::toString).toList());
        plugin.saveConfig();
    }

    public boolean isAllowed(UUID uuid) {
        // If whitelist disabled, allow everyone
        if (!plugin.getConfig().getBoolean("whitelist.enabled", false)) return true;
        return whitelist.contains(uuid);
    }

    public boolean add(UUID uuid) {
        boolean added = whitelist.add(uuid);
        if (added) save();
        return added;
    }

    public boolean remove(UUID uuid) {
        boolean removed = whitelist.remove(uuid);
        if (removed) save();
        return removed;
    }

    public Set<UUID> list() { return Set.copyOf(whitelist); }
}
