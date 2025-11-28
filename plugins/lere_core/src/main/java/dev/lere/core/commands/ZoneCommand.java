package dev.lere.core.commands;

import dev.lere.core.LereCorePlugin;
import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.World;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;

import java.util.logging.Level;

public class ZoneCommand implements CommandExecutor {

    private final LereCorePlugin plugin;

    public ZoneCommand(LereCorePlugin plugin) {
        this.plugin = plugin;
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player)) {
            sender.sendMessage("Only players can use this command.");
            return true;
        }

        Player player = (Player) sender;

        if (args.length == 0) {
            player.sendMessage("Usage: /zone join <name> OR /zone leave");
            return true;
        }

        String sub = args[0].toLowerCase();
        switch (sub) {
            case "join":
                if (args.length < 2) {
                    player.sendMessage("Usage: /zone join <name>");
                    return true;
                }
                String zone = args[1].toLowerCase();
                joinZone(player, zone);
                return true;
            case "leave":
                leaveZone(player);
                return true;
            default:
                player.sendMessage("Unknown subcommand. Use join or leave.");
                return true;
        }
    }

    private void joinZone(Player player, String zoneName) {
        // Read zone config from config.yml: zones.<name> -> world, x, y, z, yaw, pitch
        String base = "zones." + zoneName + ".";
        if (!plugin.getConfig().contains(base + "world")) {
            player.sendMessage("Zone '" + zoneName + "' not found.");
            return;
        }

        String worldName = plugin.getConfig().getString(base + "world");
        double x = plugin.getConfig().getDouble(base + "x");
        double y = plugin.getConfig().getDouble(base + "y");
        double z = plugin.getConfig().getDouble(base + "z");
        float yaw = (float) plugin.getConfig().getDouble(base + "yaw", 0.0);
        float pitch = (float) plugin.getConfig().getDouble(base + "pitch", 0.0);

        World world = Bukkit.getWorld(worldName);
        if (world == null) {
            player.sendMessage("Zone world '" + worldName + "' not loaded on server.");
            plugin.getLogger().log(Level.WARNING, "Zone world not found: " + worldName);
            return;
        }

        Location target = new Location(world, x, y, z, yaw, pitch);

        // Teleport the player
        player.teleport(target);
        player.sendMessage("You have joined zone: " + zoneName);

        // TODO: implement visibility toggles and ghost spawning (stubbed now)
        plugin.getLogger().info(player.getName() + " joined zone " + zoneName);
    }

    private void leaveZone(Player player) {
        // For now, we just teleport player to spawn of their current world
        World world = player.getWorld();
        Location spawn = world.getSpawnLocation();
        player.teleport(spawn);
        player.sendMessage("You have left your zone and returned to world spawn.");
        plugin.getLogger().info(player.getName() + " left zone and returned to spawn.");

        // TODO: restore visibility state and remove ghost entities
    }
}
