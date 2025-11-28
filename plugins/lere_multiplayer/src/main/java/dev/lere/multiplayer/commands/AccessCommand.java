package dev.lere.multiplayer.commands;

import dev.lere.multiplayer.LereMultiplayerPlugin;
import dev.lere.multiplayer.access.AccessManager;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;

import java.util.UUID;

public class AccessCommand implements CommandExecutor {
    private final LereMultiplayerPlugin plugin;
    private final AccessManager manager;

    public AccessCommand(LereMultiplayerPlugin plugin) {
        this.plugin = plugin;
        this.manager = plugin.getAccessManager();
    }

    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!sender.hasPermission("lere.multiplayer.admin")) {
            sender.sendMessage("You don't have permission to manage access.");
            return true;
        }

        if (args.length == 0) {
            sender.sendMessage("Usage: /access add|remove|list <uuid>");
            return true;
        }

        String action = args[0].toLowerCase();
        try {
            switch (action) {
                case "add":
                    if (args.length < 2) { sender.sendMessage("Usage: /access add <uuid>"); return true; }
                    UUID toAdd = UUID.fromString(args[1]);
                    if (manager.add(toAdd)) sender.sendMessage("Added to whitelist: " + toAdd);
                    else sender.sendMessage("UUID already present: " + toAdd);
                    return true;
                case "remove":
                    if (args.length < 2) { sender.sendMessage("Usage: /access remove <uuid>"); return true; }
                    UUID toRem = UUID.fromString(args[1]);
                    if (manager.remove(toRem)) sender.sendMessage("Removed from whitelist: " + toRem);
                    else sender.sendMessage("UUID not found: " + toRem);
                    return true;
                case "list":
                    var list = manager.list();
                    sender.sendMessage("Whitelist entries: " + list.size());
                    list.forEach(u -> sender.sendMessage(" - " + u.toString()));
                    return true;
                case "reload":
                    manager.load();
                    sender.sendMessage("Whitelist reloaded.");
                    return true;
                default:
                    sender.sendMessage("Unknown action: " + action);
                    return true;
            }
        } catch (IllegalArgumentException ex) {
            sender.sendMessage("Invalid UUID format: " + (args.length>1?args[1]:""));
            return true;
        }
    }
}
