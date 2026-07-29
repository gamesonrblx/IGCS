-- Replace only the `if parsed.kind == "admin" then ... end` branch in the
-- current ChatServer.server module with this block. The normal chat forward
-- happens on the client (transport for admin tools); bubbles use the same
-- IGCS path as global chat so visuals stay consistent.
if parsed.kind == "admin" then
	local filtered = filterForBroadcast(player, parsed.message)
	if filtered then
		-- Same bubble style as normal / team chat (Chat:Chat), not TextChat bubbles.
		bubbleChatForPlayer(player, filtered)
		broadcastMessageRE:FireAllClients({
			scope = "global",
			userId = player.UserId,
			displayName = player.DisplayName,
			username = player.Name,
			text = filtered,
			system = false,
			t = os.time(),
		})
	end
	return
end

