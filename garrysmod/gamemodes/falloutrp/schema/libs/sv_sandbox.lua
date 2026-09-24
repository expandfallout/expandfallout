--[[
	The Q menu: who may spawn what, and a record of everything that was.

	Sandbox hands every player the whole spawn menu by default and Helix does
	not take it away. On a roleplay server that is a stack of free weapons, a
	free vehicle, and a physics gun pointed at somebody's house - so every one
	of those routes is a permission here, and every one of them is logged
	whether it was allowed or refused.

	REFUSALS ARE LOGGED TOO, and that is the half that matters. "Nobody spawned
	a minigun" is not the same as "somebody tried to spawn a minigun eleven
	times", and only one of those tells you who to watch.

	EVERY SANDBOX HOOK IS COVERED, not the obvious ones. `PlayerSpawnProp` is
	what people think of; `PlayerGiveSWEP` is the one that hands you a weapon
	without spawning anything, and it is the one that gets forgotten.
]]

if (not SERVER) then return end

--[[
	What each spawn route needs, and what it is called in a log.

	A table rather than eleven near-identical hooks, because they differ only
	in their name and their permission - and eleven copies of the same eight
	lines is eight lines that can drift apart.
]]
local ROUTES = {
	{hook = "PlayerSpawnProp", permission = "spawn.prop", what = "prop"},
	{hook = "PlayerSpawnSWEP", permission = "spawn.weapon", what = "weapon"},
	{hook = "PlayerGiveSWEP", permission = "spawn.weapon", what = "weapon"},
	{hook = "PlayerSpawnSENT", permission = "spawn.entity", what = "entity"},
	{hook = "PlayerSpawnNPC", permission = "spawn.npc", what = "NPC"},
	{
		hook = "PlayerSpawnVehicle", permission = "spawn.vehicle",
		what = "vehicle"
	},
	{hook = "PlayerSpawnEffect", permission = "spawn.effect", what = "effect"},
	{
		hook = "PlayerSpawnRagdoll", permission = "spawn.ragdoll",
		what = "ragdoll"
	}
}

for _, route in ipairs(ROUTES) do
	hook.Add(route.hook, "ixSandbox", function(client, model, ...)
		local allowed = ix.admin.Can(client, route.permission)

		ix.log.Add(client, "sandboxSpawn", route.what,
			tostring(model or "?"), allowed)

		if (not allowed) then
			client:Notify("You cannot spawn " .. route.what .. "s.")

			return false
		end
	end)
end

ix.log.AddType("sandboxSpawn", function(client, what, model, allowed)
	return string.format("%s %s a %s: %s", client:Name(),
		allowed and "spawned" or "was REFUSED", what, model)
end, FLAG_WARNING)

--------------------------------------------------------------------------------
-- Tools
--------------------------------------------------------------------------------

--[[
	The tool gun, per tool.

	`tool.<name>` is checked first and `spawn.tool` is the fallback, so a
	server can hand out the whole tool gun with one permission and still take
	`tool.duplicator` back off somebody.

	NOT LOGGED PER SHOT. `CanTool` fires on every click and holding down the
	fire key on a thruster would write hundreds of lines - so a refusal is
	logged (rare, and the thing worth knowing) and a success is logged once per
	tool per player per minute.
]]
local lastTool = {}

hook.Add("CanTool", "ixSandbox", function(client, trace, tool)
	local specific = "tool." .. tostring(tool)
	local allowed = ix.admin.permissions[specific]
		and ix.admin.Can(client, specific)
		or (not ix.admin.permissions[specific]
			and ix.admin.Can(client, "spawn.tool"))

	if (not allowed) then
		ix.log.Add(client, "sandboxTool", tostring(tool), false)

		client:Notify("You cannot use the " .. tostring(tool) .. " tool.")

		return false
	end

	local key = client:SteamID() .. tool

	if ((lastTool[key] or 0) < CurTime()) then
		lastTool[key] = CurTime() + 60

		ix.log.Add(client, "sandboxTool", tostring(tool), true)
	end
end)

ix.log.AddType("sandboxTool", function(client, tool, allowed)
	return string.format("%s %s the '%s' tool.", client:Name(),
		allowed and "used" or "was REFUSED", tool)
end)

--[[
	The physics gun, and the context menu's properties.

	Both can move or delete somebody else's things, so both are gated the same
	way and both say who touched what.
]]
hook.Add("PhysgunPickup", "ixSandbox", function(client, entity)
	--[[
		PEOPLE ARE NOT PROPS, and this hook must not answer for them.

		`spawn.physgun` is about picking up somebody else's furniture;
		`player.physgun` in `sh_physgun.lua` is about picking up somebody.
		They are separate permissions on purpose - a builder rank with the
		first should not get the second.

		It is skipped rather than checked because two `hook.Add` listeners on
		one event run in `pairs` order, which is not the order they were added
		- so a version that answered for players would sometimes refuse before
		the player rule ever ran, and sometimes not, on the same server.
	]]
	if (IsValid(entity) and entity:IsPlayer()) then return end

	if (ix.admin.Can(client, "spawn.physgun")) then return end

	return false
end)

hook.Add("CanProperty", "ixSandbox", function(client, property, entity)
	--[[
		Helix's own admin-only properties already check for themselves and the
		schema adds several more, so this is about SANDBOX's - remover,
		ignite, keep upright and the rest, which are the ones that can be used
		on somebody else's property.
	]]
	local allowed = ix.admin.Can(client, "spawn.property")

	ix.log.Add(client, "sandboxProperty", tostring(property),
		IsValid(entity) and entity:GetClass() or "?", allowed)

	if (not allowed) then return false end
end)

ix.log.AddType("sandboxProperty", function(client, property, class, allowed)
	return string.format("%s %s the '%s' property on %s.", client:Name(),
		allowed and "used" or "was REFUSED", property, class)
end)

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

--[[
	`gmod_cleanup` and `gmod_admin_cleanup`, behind a permission.

	THE ONLY WAY IN IS TO REPLACE THE COMMAND. Both live in
	`includes/modules/cleanup.lua` as plain `concommand.Add` calls with no hook
	of any kind - the admin one's entire check is `if (IsValid(pl) &&
	!pl:IsAdmin()) then return end` - so there is nothing to listen to and
	nothing to return false from.

	`concommand.GetTable()` hands back the live function, which is what makes
	this a wrap rather than a reimplementation: the original still does the
	work, and everything it knows about cleanup types and the per-player list
	stays where it is.

	The refusal is LOGGED. Somebody trying to wipe the map is exactly the thing
	the admin log exists for, and a silent refusal tells nobody.
]]
local CLEANUP = {
	gmod_cleanup = {
		permission = "cleanup.self",
		what = "clean up their own props"
	},
	gmod_admin_cleanup = {
		permission = "cleanup.map",
		what = "clean up the whole map"
	}
}

local function WrapCleanup()
	local commands = concommand.GetTable()

	if (not commands) then return false end

	local found = 0

	for name, info in pairs(CLEANUP) do
		local original = commands[name]

		if (not original or info.wrapped) then continue end

		info.wrapped = true
		found = found + 1

		concommand.Add(name, function(client, command, arguments, text)
			--[[
				The console is not a player and is not stopped. An admin at the
				server console has already got every permission there is, and
				refusing them would make the command unusable from the one
				place it is safe to run.
			]]
			if (IsValid(client) and client:IsPlayer()) then
				if (not ix.admin.Can(client, info.permission)) then
					client:Notify("You cannot " .. info.what .. ".")

					ix.log.Add(client, "sandboxCleanup", command, false)

					return
				end

				ix.log.Add(client, "sandboxCleanup", command, true)
			end

			return original(client, command, arguments, text)
		end, nil, "", {FCVAR_DONTRECORD})
	end

	return found > 0 or (CLEANUP.gmod_cleanup.wrapped
		and CLEANUP.gmod_admin_cleanup.wrapped)
end

if (not WrapCleanup()) then
	--[[
		The cleanup module is loaded long before any gamemode, so this
		effectively never happens - the retry is here because "effectively
		never" is how the last three silent failures in this project started.
	]]
	timer.Create("ixSandboxCleanup", 1, 10, function()
		if (WrapCleanup()) then timer.Remove("ixSandboxCleanup") end
	end)
end

ix.log.AddType("sandboxCleanup", function(client, command, allowed)
	return string.format("%s %s '%s'.", client:Name(),
		allowed and "ran" or "was REFUSED", command)
end, FLAG_DANGER)

--------------------------------------------------------------------------------
-- Everything else worth knowing about
--------------------------------------------------------------------------------

hook.Add("PlayerNoClip", "ixSandbox", function(client, state)
	--[[
		Logged rather than blocked. Helix's observer mode already decides who
		may noclip; this is the record of when they did, which is what somebody
		asking "how did they get in there" needs.
	]]
	ix.log.Add(client, "sandboxNoclip", state and "on" or "off",
		tostring(client:GetPos()))
end)

ix.log.AddType("sandboxNoclip", function(client, state, position)
	return string.format("%s turned noclip %s at %s.", client:Name(), state,
		position)
end, FLAG_DEV)

hook.Add("PlayerSpawnedProp", "ixSandbox", function(client, model, entity)
	--[[
		The entity index as well as the model, so a prop found in the world can
		be traced back to whoever put it there - which the spawn log alone
		cannot do once several people have spawned the same crate.
	]]
	if (not IsValid(entity)) then return end

	entity.ixSpawner = client:SteamID()
	entity.ixSpawnerName = client:Name()
end)

--[[
	Undo and cleanup, because "who deleted everything" is a real question.
]]
hook.Add("CanUndo", "ixSandbox", function(client, undo)
	ix.log.Add(client, "sandboxUndo", undo and undo.Name or "?")
end)

ix.log.AddType("sandboxUndo", function(client, name)
	return string.format("%s undid '%s'.", client:Name(), name)
end)
