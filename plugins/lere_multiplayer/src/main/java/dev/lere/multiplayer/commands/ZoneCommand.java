package dev.lere.multiplayer.commands;

import dev.lere.multiplayer.LereMultiplayerPlugin;
import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.World;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;

public class ZoneCommand implements CommandExecutor {
    private final LereMultiplayerPlugin plugin;

    public ZoneCommand(LereMultiplayerPlugin plugin) {
        this.plugin = plugin;
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player)) { sender.sendMessage("Only players can use this command."); return true; }
        Player p = (Player) sender;
        if (args.length == 0) { p.sendMessage("Usage: /zone join <name> | /zone leave | /zone list"); return true; }

        String sub = args[0].toLowerCase();
        if (sub.equals("join")) {
            if (args.length < 2) { p.sendMessage("Usage: /zone join <name>"); return true; }
            String name = args[1];
            var result = plugin.getZoneManager().teleportToZone(p, name);
            p.sendMessage(result.message);
            return result.success;
        } else if (sub.equals("leave")) {
            // For now, teleport to spawn (or hub)
            World w = Bukkit.getWorld(plugin.getConfig().getString("zones.hub.world", "world"));
            double x = plugin.getConfig().getDouble("zones.hub.x", 0.0);
            double y = plugin.getConfig().getDouble("zones.hub.y", 64.0);
            double z = plugin.getConfig().getDouble("zones.hub.z", 0.0);
            float yaw = (float) plugin.getConfig().getDouble("zones.hub.yaw", 0.0);
            float pitch = (float) plugin.getConfig().getDouble("zones.hub.pitch", 0.0);
            if (w != null) p.teleport(new Location(w, x, y, z, yaw, pitch));
            p.sendMessage("Left zone.");
            return true;
        }

        else if (sub.equals("list")) {
            var ids = plugin.getZoneManager().listZoneIds();
            if (ids.isEmpty()) { p.sendMessage("No zones are configured."); return true; }
            p.sendMessage("Available zones: " + String.join(", ", ids));
            return true;
        }

        p.sendMessage("Unknown subcommand: " + sub);
        return true;
    }
}
