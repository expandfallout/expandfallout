--[[
	Ranks: storing them, applying them, editing them.

	See `sh_usergroups.lua` for the model and why it is that shape.

	TWO SAVES, because they change for different reasons. The RANKS are
	configuration - what a moderator may do - and the MEMBERSHIPS are who is
	one. Editing a rank should not rewrite everybody's membership, and
	promoting somebody should not rewrite the rank definitions.

	BOTH ARE GLOBAL, not per schema and not per map. A rank is a fact about
	this server, and losing everybody's rank because the map changed would be a
	spectacular way to lock yourself out.
]]

if (not SERVER) then return end

util.AddNetworkString("ixGroupSet")
util.AddNetworkString("ixAdminOpen")
util.AddNetworkString("ixRankSync")
util.AddNetworkString("ixRankSave")
util.AddNetworkString("ixRankDelete")

local RANK_KEY = "adminranks"
local MEMBER_KEY = "usergroups"

local loaded = false

--- `[steamID64] = rank id`.
ix.admin.stored = ix.admin.stored or {}

function ix.admin.Save()
	if (not loaded) then return end

	ix.data.Set(RANK_KEY, ix.admin.ranks, true, true)
	ix.data.Set(MEMBER_KEY, ix.admin.stored, true, true)
end

function ix.admin.Load()
	if (loaded) then return end

	local ranks = ix.data.Get(RANK_KEY, nil, true, true)

	--[[
		NIL, NOT EMPTY. A server that has never been configured gets the
		default ladder; one whose owner has deleted ranks down to nothing keeps
		what they chose. Same distinction the bench seeder makes, and for the
		same reason - those are different states and `ix.data.Get` tells them
		apart.
	]]
	if (istable(ranks) and table.Count(ranks) > 0) then
		ix.admin.ranks = ranks
	else
		ix.admin.ranks = ix.admin.DefaultRanks()
	end

	--[[
		`user` and `owner` are put back if they are missing, whatever else was
		stored. They are the floor and the escape hatch; a saved file without
		them is a server nobody can administer.
	]]
	local defaults = ix.admin.DefaultRanks()

	for id in pairs(ix.admin.protected) do
		if (not ix.admin.ranks[id]) then
			ix.admin.ranks[id] = defaults[id]
		end
	end

	ix.admin.stored = ix.data.Get(MEMBER_KEY, {}, true, true) or {}

	--[[
		AFTER the memberships are read, not before - it rewrites them, and it
		was originally above this line where `ix.admin.stored` was still the
		empty table from file scope. Anybody stored as `owner` would have been
		left as `owner`, pointing at a rank that no longer exists.
	]]
	if (ix.admin.ranks.owner) then
		for steamID, member in pairs(ix.admin.stored) do
			if (member == "owner") then ix.admin.stored[steamID] = "root" end
		end

		ix.admin.ranks.owner = nil
	end

	loaded = true

	for _, client in ipairs(player.GetAll()) do
		ix.admin.Apply(client)
	end

	ix.admin.SendAll()

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] %d rank(s), %d stored membership(s)\n",
		table.Count(ix.admin.ranks), table.Count(ix.admin.stored)))
end

hook.Add("LoadData", "ixUsergroups", ix.admin.Load)
hook.Add("PostLoadData", "ixUsergroups", ix.admin.Load)
timer.Simple(5, ix.admin.Load)

--------------------------------------------------------------------------------
-- Applying
--------------------------------------------------------------------------------

--[[
	Put a player into the rank they are stored under.

	Sets the networked fine rank, which `ix.admin.GetRankID` reads, and the
	coarse GMod one underneath it - see the long note in `sh_usergroups.lua`
	about the forty-eight `IsAdmin()` checks this keeps working.
]]
function ix.admin.Apply(client)
	if (not IsValid(client)) then return end

	local stored = ix.admin.stored[client:SteamID64()]

	--[[
		Somebody with no stored rank keeps whatever the server itself gave
		them - `users.txt`, or another admin mod - rather than being demoted on
		join.
	]]
	if (not stored or not ix.admin.ranks[stored]) then
		client:SetNetVar("ixGroup", ix.admin.GetRankID(client))

		return
	end

	local rank = ix.admin.Rank(stored)

	client:SetNetVar("ixGroup", rank.id)
	client:SetUserGroup(rank.native or "user")
end

hook.Add("PlayerInitialSpawn", "ixUsergroups", function(client)
	--[[
		Deferred a tick. `SetNetVar` on a player who has not finished spawning
		is a value nobody receives, and the join is the one moment the rank
		absolutely has to be right.
	]]
	timer.Simple(1, function()
		if (not IsValid(client)) then return end

		ix.admin.Apply(client)
		ix.admin.SendAll(client)
	end)
end)

--[[
	The rank definitions, sent to everybody.

	Not secret, and the menu needs them to draw anything at all - the player
	list shows each person's rank name and colour, which is a lookup the client
	has to be able to do without a round trip.
]]
function ix.admin.SendAll(client)
	net.Start("ixRankSync")
		net.WriteTable(ix.admin.ranks)
	if (IsValid(client)) then net.Send(client) else net.Broadcast() end
end

--------------------------------------------------------------------------------
-- Membership
--------------------------------------------------------------------------------

--[[
	Move somebody into a rank. Returns `true`, or `false, reason`.

	Every rule is checked here rather than at the command, because the command
	is not the only way in - the menu sends its own message - and a rule
	enforced in two places is a rule enforced in one and a half.
]]
function ix.admin.SetGroup(client, target, rankID)
	local rank = ix.admin.ranks[rankID]

	if (not rank) then return false, "There is no such rank." end

	if (not ix.admin.Can(client, "rank.manage")) then
		return false, "You cannot change ranks."
	end

	if (target:SteamID64() == ix.admin.rootSteamID) then
		return false, "That account is root and cannot be changed."
	end

	if (not ix.admin.Outranks(client, target)) then
		return false, "They outrank you, or match you."
	end

	--[[
		Nobody may hand out a rank at or above their own, or the first thing
		anybody with `rank.manage` does is make themselves an owner.
	]]
	if (IsValid(client) and rank.immunity >= ix.admin.Immunity(client)) then
		return false, "That is at or above your own rank."
	end

	local steamID = target:SteamID64()
	local before = ix.admin.GetRankID(target)

	if (rankID == "user") then
		ix.admin.stored[steamID] = nil
	else
		ix.admin.stored[steamID] = rankID
	end

	ix.admin.Save()
	ix.admin.Apply(target)

	--[[
		ANNOUNCED, so anything that depends on what a rank may do can catch up
		without polling - `sv_commandsync.lua` rebuilds that player's command
		list on it, since the list IS what their rank may run.
	]]
	hook.Run("OnAdminRankChanged", target, rankID, before)

	ix.log.Add(client, "adminGroup", target:Name(), target:SteamID(), before,
		rankID)

	return true
end

net.Receive("ixGroupSet", function(length, client)
	local target = net.ReadEntity()
	local rankID = net.ReadString()

	if (not IsValid(target) or not target:IsPlayer()) then return end

	local ok, reason = ix.admin.SetGroup(client, target, rankID)

	client:Notify(ok and string.format("%s is now %s.", target:Name(),
		ix.admin.Rank(rankID).name) or reason)

	if (ok and IsValid(target)) then
		target:Notify(string.format("You are now %s.",
			ix.admin.Rank(rankID).name))
	end
end)

--------------------------------------------------------------------------------
-- Editing the ranks themselves
--------------------------------------------------------------------------------

--[[
	Write a rank, new or edited. Returns `true`, or `false, reason`.

	NOBODY MAY CREATE A RANK AT OR ABOVE THEIR OWN IMMUNITY, for exactly the
	reason they cannot hand one out: otherwise `rank.manage` is a single step
	away from owning the server.
]]
function ix.admin.SaveRank(client, data)
	if (not ix.admin.Can(client, "rank.manage")) then
		return false, "You cannot edit ranks."
	end

	local id = string.lower(string.Trim(tostring(data.id or "")))

	id = string.gsub(id, "[^%w_]", "")

	if (id == "") then return false, "That is not a rank id." end

	local existing = ix.admin.ranks[id]

	if (existing and not ix.admin.Outranks(client, nil)
	and existing.immunity >= ix.admin.Immunity(client)) then
		return false, "That rank is at or above your own."
	end

	local immunity = math.Clamp(math.floor(tonumber(data.immunity) or 1), 0,
		100)

	if (IsValid(client) and immunity >= ix.admin.Immunity(client)) then
		return false, "That immunity is at or above your own."
	end

	--[[
		The protected pair keep their immunity whatever is sent. `user` at
		anything but the bottom, or `owner` at anything but the top, is a
		server that cannot be administered - and this message is reachable by
		anybody who can send a netstring.
	]]
	if (id == "user") then immunity = 0 end
	if (id == "owner") then immunity = 100 end

	local inherit = data.inherit and string.lower(data.inherit) or nil

	if (inherit == id) then inherit = nil end
	if (inherit and not ix.admin.ranks[inherit]) then inherit = nil end

	local permissions = {}

	for permission, value in pairs(data.permissions or {}) do
		--- Only permissions that exist, and only as a real boolean.
		if (ix.admin.permissions[permission]) then
			permissions[permission] = value == true
		end
	end

	ix.admin.ranks[id] = {
		id = id,
		name = string.sub(tostring(data.name or id), 1, 32),
		inherit = inherit,
		immunity = immunity,
		native = existing and existing.native
			or (immunity >= 50 and "superadmin"
				or immunity >= 40 and "admin" or "user"),
		color = existing and existing.color or Color(200, 200, 200),
		banLimit = math.max(math.floor(tonumber(data.banLimit) or 0), 0),

		--[[
			HOW MANY CHARACTERS SOMEBODY IN THIS RANK MAY HAVE.

			0 means "whatever `maxCharacters` says", so a rank nobody has
			thought about behaves exactly as it did before this existed - which
			is what keeps a new field from quietly changing every rank on the
			server. See `ix.admin.MaxCharacters`.
		]]
		maxCharacters = math.Clamp(
			math.floor(tonumber(data.maxCharacters) or 0), 0, 64),
		root = existing and existing.root or nil,
		permissions = permissions
	}

	ix.admin.Save()
	ix.admin.SendAll()

	--- Everybody in it gets the new rules immediately, not on next join.
	for _, other in ipairs(player.GetAll()) do
		if (ix.admin.GetRankID(other) == id) then
			ix.admin.Apply(other)
		end
	end

	ix.log.Add(client, "adminRankSave", id, immunity)

	return true
end

net.Receive("ixRankSave", function(length, client)
	local ok, reason = ix.admin.SaveRank(client, net.ReadTable() or {})

	client:Notify(ok and "Rank saved." or reason)
end)

net.Receive("ixRankDelete", function(length, client)
	if (not ix.admin.Can(client, "rank.manage")) then return end

	local id = net.ReadString()
	local rank = ix.admin.ranks[id]

	if (not rank) then return end

	if (ix.admin.protected[id]) then
		client:Notify("That rank cannot be deleted.")

		return
	end

	if (IsValid(client) and rank.immunity >= ix.admin.Immunity(client)) then
		client:Notify("That rank is at or above your own.")

		return
	end

	--[[
		Everybody in it, and everything inheriting from it, is moved DOWN
		rather than left pointing at a rank that no longer exists - which would
		make `RankCan` walk to a nil and answer false for people who should
		still have their permissions.
	]]
	local moved = 0

	for steamID, member in pairs(ix.admin.stored) do
		if (member == id) then
			ix.admin.stored[steamID] = rank.inherit ~= "user" and rank.inherit
				or nil
			moved = moved + 1
		end
	end

	for _, other in pairs(ix.admin.ranks) do
		if (other.inherit == id) then other.inherit = rank.inherit end
	end

	ix.admin.ranks[id] = nil

	ix.admin.Save()
	ix.admin.SendAll()

	for _, other in ipairs(player.GetAll()) do
		ix.admin.Apply(other)
	end

	client:Notify(string.format("Deleted %s - %d member(s) moved.", rank.name,
		moved))

	ix.log.Add(client, "adminRankDelete", id, moved)
end)

ix.log.AddType("adminGroup", function(client, name, steamID, before, after)
	return string.format("%s changed %s (%s) from %s to %s.",
		client and client:Name() or "the console", name, steamID, before,
		after)
end, FLAG_DANGER)

ix.log.AddType("adminRankSave", function(client, id, immunity)
	return string.format("%s saved the rank '%s' at immunity %d.",
		client and client:Name() or "the console", id, immunity)
end, FLAG_DANGER)

ix.log.AddType("adminRankDelete", function(client, id, moved)
	return string.format("%s deleted the rank '%s' - %d member(s) moved.",
		client and client:Name() or "the console", id, moved)
end, FLAG_DANGER)

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

ix.command.Add("SetGroup", {
	description = "Move a player into a rank.",
	arguments = {ix.type.player, ix.type.string},

	--[[
		NOT `adminOnly`. Helix's flag means `IsAdmin`, which is the two-level
		system this file exists to replace.
	]]
	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "rank.manage")
	end,

	OnRun = function(self, client, target, rankID)
		rankID = string.lower(string.Trim(rankID))

		local ok, reason = ix.admin.SetGroup(client, target, rankID)

		if (not ok) then return reason end

		return string.format("%s is now %s.", target:Name(),
			ix.admin.Rank(rankID).name)
	end
})

ix.command.Add("Groups", {
	description = "List the ranks, and who is in them.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "player.list")
	end,

	OnRun = function(self, client)
		for _, rank in ipairs(ix.admin.SortedRanks()) do
			local names = {}

			for _, other in ipairs(player.GetAll()) do
				if (ix.admin.GetRankID(other) == rank.id) then
					names[#names + 1] = other:Name()
				end
			end

			client:ChatPrint(string.format("%-12s immunity %-4d %s", rank.id,
				rank.immunity, #names > 0 and table.concat(names, ", ")
					or "nobody on"))
		end

		return string.format("%d rank(s), %d stored membership(s).",
			table.Count(ix.admin.ranks), table.Count(ix.admin.stored))
	end
})
