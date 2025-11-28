package dev.lere.multiplayer.listeners;

import dev.lere.multiplayer.LereMultiplayerPlugin;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;

public class JoinListener implements Listener {
    private final LereMultiplayerPlugin plugin;

    public JoinListener(LereMultiplayerPlugin plugin) { this.plugin = plugin; }

    @EventHandler
    public void onPlayerJoin(PlayerJoinEvent event) {
        var player = event.getPlayer();
        var am = plugin.getAccessManager();
        boolean allowed = am == null ? true : am.isAllowed(player.getUniqueId());
        if (!allowed) {
            if (plugin.getConfig().getBoolean("whitelist.enabled", false)) {
                player.kickPlayer("Server is private. Contact an admin for access.");
            }
        }
    }
}
