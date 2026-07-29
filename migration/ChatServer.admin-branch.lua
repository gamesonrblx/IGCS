-- Replace only the `if parsed.kind == "admin" then ... end` branch in the
-- current ChatServer.server module with this block. The normal chat forward
-- happens on the client; this is deliberately free of Adonis or Bindable APIs.
if parsed.kind == "admin" then
	local filtered = filterForBroadcast(player, parsed.message)
	if filtered then
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

