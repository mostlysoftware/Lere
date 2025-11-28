package dev.lere.multiplayer.zone;

import dev.lere.multiplayer.LereMultiplayerPlugin;
import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.World;
import org.bukkit.entity.Player;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;

public class ZoneManager {
    private final LereMultiplayerPlugin plugin;
    private final Map<String, Zone> zones = new HashMap<>();

    public ZoneManager(LereMultiplayerPlugin plugin) {
        this.plugin = plugin;
    }

    public void loadFromConfig() {
        var cfg = plugin.getConfig();
        // Clear previous definitions before loading
        zones.clear();

        if (!cfg.isConfigurationSection("zones")) {
            // create default hub
            plugin.getLogger().info("No zones defined; creating default hub zone");
            cfg.set("zones.hub.world", "world");
            cfg.set("zones.hub.x", 0.0);
            cfg.set("zones.hub.y", 64.0);
            cfg.set("zones.hub.z", 0.0);
            cfg.set("zones.hub.yaw", 0.0);
            cfg.set("zones.hub.pitch", 0.0);
            plugin.saveConfig();
        }

        var sec = cfg.getConfigurationSection("zones");
        if (sec == null) return;

        for (String key : sec.getKeys(false)) {
            try {
                String base = "zones." + key + ".";
                String worldName = cfg.getString(base + "world", null);
                if (worldName == null || worldName.isBlank()) {
                    plugin.getLogger().warning("Zone '" + key + "' missing 'world' value; skipping.");
                    continue;
                }
                World w = Bukkit.getWorld(worldName);
                if (w == null) {
                    plugin.getLogger().warning("Zone '" + key + "' references unknown world '" + worldName + "'; skipping.");
                    continue;
                }

                double x = cfg.getDouble(base + "x", Double.NaN);
                double y = cfg.getDouble(base + "y", Double.NaN);
                double z = cfg.getDouble(base + "z", Double.NaN);

                if (!Double.isFinite(x) || !Double.isFinite(y) || !Double.isFinite(z)) {
                    plugin.getLogger().warning("Zone '" + key + "' has invalid coordinates; skipping.");
                    continue;
                }

                // clamp Y into world bounds to avoid teleporting into the void/out-of-range
                int max = w.getMaxHeight();
                if (y < 0 || y > max) {
                    plugin.getLogger().warning("Zone '" + key + "' Y coordinate " + y + " out of world bounds (0-" + max + "); clamping to safe range.");
                    if (y < 0) y = 1.0;
                    if (y > max) y = Math.max(1.0, max - 2);
                }

                float yaw = (float) cfg.getDouble(base + "yaw", 0.0);
                float pitch = (float) cfg.getDouble(base + "pitch", 0.0);

                Zone zdef = new Zone(key, worldName, x, y, z, yaw, pitch);
                zones.put(key.toLowerCase(), zdef);
                plugin.getLogger().info("Loaded zone: " + key + " -> world=" + worldName + " @ (" + x + "," + y + "," + z + ")");
            } catch (Exception ex) {
                plugin.getLogger().warning("Failed to load zone '" + key + "': " + ex.getMessage());
            }
        }

        // Ensure at least the hub exists
        if (zones.isEmpty()) {
            plugin.getLogger().info("No valid zones loaded; ensuring default hub exists.");
            cfg.set("zones.hub.world", cfg.getString("zones.hub.world", "world"));
            cfg.set("zones.hub.x", cfg.getDouble("zones.hub.x", 0.0));
            cfg.set("zones.hub.y", cfg.getDouble("zones.hub.y", 64.0));
            cfg.set("zones.hub.z", cfg.getDouble("zones.hub.z", 0.0));
            cfg.set("zones.hub.yaw", cfg.getDouble("zones.hub.yaw", 0.0));
            cfg.set("zones.hub.pitch", cfg.getDouble("zones.hub.pitch", 0.0));
            plugin.saveConfig();
            // attempt to load hub now
            loadFromConfig();
        }
    }

    public Zone getZone(String id) {
        if (id == null) return null;
        return zones.get(id.toLowerCase());
    }

    public Set<String> listZoneIds() {
        // Return the original IDs as configured (case-preserving)
        var s = new java.util.LinkedHashSet<String>();
        for (Zone z : zones.values()) s.add(z.getId());
        return Collections.unmodifiableSet(s);
    }

    public TeleportResult teleportToZone(Player player, String id) {
        Zone z = getZone(id);
        if (z == null) return new TeleportResult(false, "Unknown zone: " + id);
        World w = Bukkit.getWorld(z.getWorldName());
        if (w == null) return new TeleportResult(false, "Zone world not loaded: " + z.getWorldName());
        Location loc = new Location(w, z.getX(), z.getY(), z.getZ(), z.getYaw(), z.getPitch());
        try {
            player.teleport(loc);
            return new TeleportResult(true, "Teleported to zone: " + id);
        } catch (Exception ex) {
            plugin.getLogger().warning("Teleport failed for " + player.getName() + " to zone " + id + ": " + ex.getMessage());
            return new TeleportResult(false, "Teleport failed: " + ex.getMessage());
        }
    }

    public static class TeleportResult {
        public final boolean success;
        public final String message;
        public TeleportResult(boolean success, String message) { this.success = success; this.message = message; }
    }
}
