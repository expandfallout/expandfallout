--[[
	Faction spawns - the server half.

	Three jobs: keep the list, hold a dead player until they choose, and put
	them where they chose.

	HOLDING THEM IS DONE BY BLOCKING HELIX'S RESPAWN, not by replacing it.
	`GM:PlayerDeathThink` respawns once `deathTime` has passed; a `hook.Add`
	listener runs first and, by returning a value, stops the gamemode method
	from running at all. So the player simply stays dead until they pick, and
	every other thing Helix does around death is untouched.
]]

if (not SERVER) then return end

util.AddNetworkString("ixSpawnChoices")
util.AddNetworkString("ixSpawnPick")

function ix.spawns.Save()
	--[[
		The list is written whole. `ix.data` cannot encode a Vector as
		anything but a string, and it reads them back as Vectors, so the
		positions survive the round trip - the same way Helix's own container
		save does.
	]]
	ix.data.Set("factionspawns", ix.spawns.list)
end

function ix.spawns.Load()
	ix.spawns.list = ix.data.Get("factionspawns", {}) or {}

	local factions, points = 0, 0

	for _, list in pairs(ix.spawns.list) do
		factions = factions + 1
		points = points + #list
	end

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] loaded %d spawn point(s) across %d faction(s)\n",
		points, factions))
end

function ix.spawns.Add(faction, name, position, angles)
	ix.spawns.list[faction] = ix.spawns.list[faction] or {}

	table.insert(ix.spawns.list[faction], {
		name = name,
		position = position,
		--[[
			Only the yaw is kept. Pitch and roll would have a player spawn
			looking at the sky or lying on their side, which is what happens
			when an admin sets a spawn while looking at the floor.
		]]
		angles = Angle(0, angles.y, 0)
	})

	ix.spawns.Save()

	return #ix.spawns.list[faction]
end

function ix.spawns.Remove(faction, index)
	local list = ix.spawns.list[faction]

	if (not list or not list[index]) then return false end

	table.remove(list, index)

	if (#list == 0) then
		ix.spawns.list[faction] = nil
	end

	ix.spawns.Save()

	return true
end

--[[
	Offer the choices.

	Sent once, when the death timer runs out, rather than the moment they die -
	a menu that appears before the ragdoll has landed reads as an interruption
	rather than as a consequence.
]]
function ix.spawns.Offer(client)
	local character = client:GetCharacter()
	local faction = ix.spawns.GetFaction(character)
	local points = faction and ix.spawns.Get(faction) or {}

	if (#points == 0) then return false end

	client.ixAwaitingSpawn = true

	net.Start("ixSpawnChoices")
		net.WriteUInt(#points, 8)

		for _, point in ipairs(points) do
			net.WriteString(point.name or "Unnamed")
		end
	net.Send(client)

	return true
end

--[[
	Hold the player dead until they pick.

	Returning a value here stops `GM:PlayerDeathThink`, which is the thing that
	would otherwise call `client:Spawn()` the moment the timer expired.
]]
hook.Add("PlayerDeathThink", "ixSpawns", function(client)
	if (not client:GetCharacter()) then return end

	local deathTime = client:GetNetVar("deathTime")

	if (not deathTime or deathTime > CurTime()) then return end

	if (client.ixAwaitingSpawn) then return false end

	--[[
		The offer is made once, at the moment the timer runs out. If the
		faction has nowhere of its own this returns false and the player falls
		through to Helix's normal respawn on the very same tick, so nothing
		waits for a menu that is not coming.
	]]
	if (ix.spawns.Offer(client)) then return false end
end)

net.Receive("ixSpawnPick", function(length, client)
	if (not client.ixAwaitingSpawn) then return end

	local index = net.ReadUInt(8)
	local character = client:GetCharacter()
	local faction = ix.spawns.GetFaction(character)
	local points = faction and ix.spawns.Get(faction) or {}
	local point = points[index]

	--[[
		Re-validated rather than trusted. The client is naming an index in a
		list it was sent, and an admin may have deleted a spawn point in
		between - and a bad index must not be a way to spawn at the origin.
	]]
	if (not point) then return end

	client.ixAwaitingSpawn = nil
	client.ixChosenSpawn = point

	client:Spawn()
end)

--[[
	Put them where they chose.

	On a zero timer so this runs after everything else that touches position on
	spawn - Helix's own loadout, the schema's, and anything a plugin adds. A
	`SetPos` that runs before another one is a `SetPos` that did nothing.
]]
hook.Add("PlayerSpawn", "ixSpawns", function(client)
	local point = client.ixChosenSpawn

	if (not point) then return end

	client.ixChosenSpawn = nil

	timer.Simple(0, function()
		if (not IsValid(client) or not client:Alive()) then return end

		client:SetPos(point.position)
		client:SetEyeAngles(point.angles or angle_zero)
	end)
end)

--[[
	A player who leaves while choosing must not come back stuck.

	`ixAwaitingSpawn` is a runtime field and dies with the session anyway; this
	is here for the case where they reconnect into the same session, where it
	would otherwise still be set and `PlayerDeathThink` would hold them dead
	forever with no menu on screen.
]]
hook.Add("PlayerDisconnected", "ixSpawns", function(client)
	client.ixAwaitingSpawn = nil
	client.ixChosenSpawn = nil
end)

hook.Add("LoadData", "ixSpawns", ix.spawns.Load)
hook.Add("InitPostEntity", "ixSpawns", function()
	timer.Simple(2, ix.spawns.Load)
end)

--[[
	The last-resort trigger, for the same reason the loot tables have one:
	`InitPostEntity` does not reach this schema, and a load that never runs is
	a list that the next save overwrites.
]]
timer.Simple(10, function()
	if (table.IsEmpty(ix.spawns.list)) then
		ix.spawns.Load()
	end
end)

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

--[[
	The commands for this library live in `sh_commands.lua`.
	They have to be declared on both realms or the chatbox cannot
	see them - see the header there.
]]
