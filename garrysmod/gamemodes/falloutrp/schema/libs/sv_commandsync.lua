--[[
	Telling the client which commands exist.

	Helix's chatbox lists `ix.command.list` as you type, with each command's
	description under it. That table is built where the command was DEFINED - so
	a command declared in an `sv_` file exists on the server and is invisible on
	the client, and this schema has fifty of them: `/ambush`, `/raidshield`,
	`/warreason`, `/lootlock`, half the admin verbs.

	They all WORK - the chat text is parsed on the server, which knows about
	them - so what is missing is only the list. This sends it, and the client
	registers what it does not already have.

	WHY NOT MOVE THE COMMANDS TO SHARED FILES: because most of them are
	server-side for a reason - they read the placed lootables, the raid state,
	the ban list. Moving fifty commands to make a menu complete would be moving
	the work to where it does not belong to fix a display.

	THE LIST IS BUILT PER PLAYER, and that is the part worth reading twice.

	Access on this server is decided by `ix.admin` ranks, not by the CAMI
	usergroups Helix's own `OnCheckAccess` falls back to - so a client asked to
	work out for itself whether it may run `/raidstop` would answer "no" for a
	moderator whose rank grants it. The server already knows the answer, so it
	sends only the commands that player may actually run, and the stub the
	client registers has no access check of its own.

	See `cl_commandsync.lua` for the other half.
]]

if (not SERVER) then return end

util.AddNetworkString("ixCommandList")

--[[
	What the client needs to draw a row: the name, what it says it does, and the
	syntax the preview box shows.

	`OnCheckAccess` is deliberately not sent. It is a function, it usually reads
	server state, and the answer would be stale the moment somebody's rank
	changed - which is why this list is filtered before it is sent instead.
]]
local function Build(client)
	local out = {}
	local seen = {}

	for name, command in pairs(ix.command.list) do
		--[[
			ALIASES POINT AT THE SAME TABLE, so a command with three names
			appears three times in this loop. The client wants one row per
			command, under its real name.
		]]
		if (seen[command]) then continue end

		if (not ix.command.HasAccess(client, name)) then continue end

		seen[command] = true

		out[#out + 1] = {
			name = command.name or name,
			description = command.description or "",
			syntax = command.syntax or "<none>"
		}
	end

	return out
end

function ix.command.SyncList(client)
	if (not IsValid(client)) then return end

	net.Start("ixCommandList")
		net.WriteTable(Build(client))
	net.Send(client)
end

--[[
	SENT ONCE A PLAYER IS IN, not on connect. The list is a couple of kilobytes
	and it is only useful once somebody can open a chatbox.
]]
hook.Add("PlayerLoadedCharacter", "ixCommandSync", function(client)
	timer.Simple(3, function()
		if (IsValid(client)) then ix.command.SyncList(client) end
	end)
end)

--[[
	AND AGAIN WHEN A RANK CHANGES, because the list is what that rank may run:
	somebody promoted mid-session would otherwise keep the shorter list until
	they reconnected, which is exactly when they are being told to go and use
	the commands they have just been given.
]]
hook.Add("OnAdminRankChanged", "ixCommandSync", function(target)
	if (not IsValid(target)) then return end

	timer.Simple(0.5, function()
		if (IsValid(target)) then ix.command.SyncList(target) end
	end)
end)

--- For anybody who wants their list rebuilt without reconnecting.
concommand.Add("fo_commands", function(client)
	if (not IsValid(client)) then return end

	ix.command.SyncList(client)
	client:ChatPrint("Command list refreshed.")
end)
