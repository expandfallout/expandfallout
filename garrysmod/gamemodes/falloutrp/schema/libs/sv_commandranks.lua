--[[
	Which rank may run which command.

	Helix decides command access at REGISTRATION - `adminOnly`, `superAdminOnly`
	or a CAMI privilege baked into an `OnCheckAccess` when the command is
	written. That is fine until you want `/charsetmoney` to be superadmin on
	your server and `/charsetclass` to be moderator, at which point the answer
	is "edit the file", and every update overwrites it.

	SO EVERY COMMAND'S CHECK IS WRAPPED, ONCE, and consults an override table
	first. It covers Helix's commands and this schema's identically, because
	`ix.command.Run` calls `OnCheckAccess` on both and neither knows the
	difference.

	AN OVERRIDE IS A RANK, NOT A PERMISSION. Permissions describe abilities and
	are worth naming; there are a hundred-odd commands and inventing a
	permission for each would be a registry nobody reads. "This command needs
	moderator or above" is what somebody setting it actually means.

	WITH NO OVERRIDE, THE COMMAND'S OWN CHECK STANDS. Wrapping is additive:
	a server that never opens this screen behaves exactly as Helix intended.
]]

if (not SERVER) then return end

util.AddNetworkString("ixCommandRankSync")
util.AddNetworkString("ixCommandRankSet")
util.AddNetworkString("ixCommandExclude")

local KEY = "commandranks"
local EXCLUDE_KEY = "commandexcludes"
local loaded = false

--- `[lowercase command name] = rank id`.
ix.admin.commandRanks = ix.admin.commandRanks or {}

--[[
	`[lowercase command name] = {[rank id] = true}` - ranks that may NOT run a
	command, whatever their immunity says.

	A SEPARATE QUESTION FROM THE MINIMUM RANK, and that is why it is a second
	table rather than a cleverer first one. The rank sets the floor, and the
	floor is a ladder: everybody at or above it gets in. An exclusion is the
	exception that a ladder cannot express - "moderators and above, except the
	event team" - and every server eventually has one of those.

	Checked BEFORE the floor, so an excluded rank is refused even when its
	immunity would clear it.
]]
ix.admin.commandExcludes = ix.admin.commandExcludes or {}

function ix.admin.SaveCommands()
	if (not loaded) then return end

	ix.data.Set(KEY, ix.admin.commandRanks, true, true)
	ix.data.Set(EXCLUDE_KEY, ix.admin.commandExcludes, true, true)
end

function ix.admin.LoadCommands()
	if (loaded) then return end

	ix.admin.commandRanks = ix.data.Get(KEY, {}, true, true) or {}
	ix.admin.commandExcludes = ix.data.Get(EXCLUDE_KEY, {}, true, true) or {}
	loaded = true

	ix.admin.SendCommands()
end

hook.Add("LoadData", "ixCommandRanks", ix.admin.LoadCommands)
hook.Add("PostLoadData", "ixCommandRanks", ix.admin.LoadCommands)
timer.Simple(6, ix.admin.LoadCommands)

function ix.admin.SendCommands(client)
	net.Start("ixCommandRankSync")
		net.WriteTable(ix.admin.commandRanks)
		net.WriteTable(ix.admin.commandExcludes)
	if (IsValid(client)) then net.Send(client) else net.Broadcast() end
end

hook.Add("PlayerInitialSpawn", "ixCommandRanks", function(client)
	timer.Simple(2, function()
		if (IsValid(client)) then ix.admin.SendCommands(client) end
	end)
end)

--------------------------------------------------------------------------------
-- The wrap
--------------------------------------------------------------------------------

--[[
	Wrap every registered command's access check.

	Done on `InitializedPlugins`, which is the first moment `ix.command.list`
	is complete - Helix's own commands, the schema's, and any plugin's. Doing
	it at file scope would catch only whatever had loaded by then.

	Each command is marked, so a `lua_refresh` cannot wrap a wrapper and leave
	a command consulting the override table twice.
]]
local function Wrap()
	local wrapped = 0

	for name, command in pairs(ix.command.list) do
		if (command.ixRankWrapped) then continue end

		command.ixRankWrapped = true

		local original = command.OnCheckAccess
		local lower = string.lower(name)

		command.OnCheckAccess = function(self, client)
			--[[
				THE EXCLUSION IS ASKED FIRST, and it is absolute: a rank named
				here cannot run the command however high it sits or whatever
				the command's own check would have said. That is what makes it
				usable as "everyone above moderator except this one group".
			]]
			local excluded = ix.admin.commandExcludes[lower]

			if (excluded and excluded[ix.admin.GetRankID(client)]) then
				return false
			end

			local override = ix.admin.commandRanks[lower]

			if (override and ix.admin.ranks[override]) then
				--[[
					The override REPLACES the original check rather than adding
					to it. Somebody who has set `/charsetmoney` to moderator
					means moderators can run it - and leaving Helix's
					`adminOnly` in the way as well would make the setting look
					broken.
				]]
				return ix.admin.Immunity(client)
					>= ix.admin.Rank(override).immunity
			end

			if (original) then return original(self, client) end

			return true
		end

		wrapped = wrapped + 1
	end

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] %d command(s) now honour rank overrides\n", wrapped))
end

hook.Add("InitializedPlugins", "ixCommandRanks", Wrap)

--------------------------------------------------------------------------------
-- Changing one
--------------------------------------------------------------------------------

--[[
	Toggling one rank's exclusion from one command.

	The same permission and the same immunity rule as setting the floor: you
	cannot exclude a rank at or above your own, because being able to would be
	a way to take a command off somebody senior to you.
]]
net.Receive("ixCommandExclude", function(length, client)
	if (not ix.admin.Can(client, "rank.manage")) then return end

	local name = string.lower(net.ReadString())
	local rankID = net.ReadString()

	local found

	for other in pairs(ix.command.list) do
		if (string.lower(other) == name) then found = other break end
	end

	if (not found or not ix.admin.ranks[rankID]) then return end

	if (IsValid(client)
	and ix.admin.Rank(rankID).immunity >= ix.admin.Immunity(client)) then
		client:Notify("That rank is at or above your own.")

		return
	end

	local list = ix.admin.commandExcludes[name] or {}

	if (list[rankID]) then
		list[rankID] = nil

		client:Notify(string.format("%s may use /%s again.",
			ix.admin.Rank(rankID).name, name))
	else
		list[rankID] = true

		client:Notify(string.format("%s may no longer use /%s.",
			ix.admin.Rank(rankID).name, name))
	end

	--- An empty table is removed rather than saved as an empty one.
	ix.admin.commandExcludes[name] = next(list) and list or nil

	ix.admin.SaveCommands()
	ix.admin.SendCommands()

	ix.log.Add(client, "commandExclude", name, ix.admin.Rank(rankID).name,
		list[rankID] and "excluded" or "allowed")
end)

net.Receive("ixCommandRankSet", function(length, client)
	if (not ix.admin.Can(client, "rank.manage")) then return end

	local name = string.lower(net.ReadString())
	local rankID = net.ReadString()

	if (not ix.command.list[name]) then
		--[[
			`ix.command.list` is keyed by the name as REGISTERED, which is
			mixed case - so a lowercase lookup misses. Both are tried rather
			than assuming either.
		]]
		local found

		for other in pairs(ix.command.list) do
			if (string.lower(other) == name) then found = other break end
		end

		if (not found) then return end
	end

	if (rankID == "" or not ix.admin.ranks[rankID]) then
		ix.admin.commandRanks[name] = nil

		client:Notify("/" .. name .. " is back to its own check.")
	else
		--[[
			Nobody may set a command to a rank at or above their own, for the
			same reason they cannot hand out such a rank: otherwise the way to
			gain a permission is to lower the bar on the command that grants
			it.
		]]
		if (IsValid(client)
		and ix.admin.Rank(rankID).immunity >= ix.admin.Immunity(client)) then
			client:Notify("That rank is at or above your own.")

			return
		end

		ix.admin.commandRanks[name] = rankID

		client:Notify(string.format("/%s now needs %s.", name,
			ix.admin.Rank(rankID).name))
	end

	ix.admin.SaveCommands()
	ix.admin.SendCommands()

	ix.log.Add(client, "adminCommandRank", name, rankID ~= "" and rankID
		or "its own check")
end)

ix.log.AddType("adminCommandRank", function(client, name, rankID)
	return string.format("%s set /%s to %s.",
		client and client:Name() or "the console", name, rankID)
end, FLAG_DANGER)

ix.log.AddType("commandExclude", function(client, name, rank, state)
	return string.format("%s %s %s from /%s.",
		client and client:Name() or "the console",
		state == "excluded" and "excluded" or "un-excluded", rank, name)
end, FLAG_DANGER)
