--[[
	Ambushes, server side.

	`/ambush` never acts on its own: it asks the caller to confirm, and the
	confirmation comes back as its own message. That is deliberate for the same
	reason the raid buttons ask - an ambush is a thing the whole faction feels
	and a mistyped command should not start one.

	    /ambush          ->  ixAmbushAsk   ->  window  ->  ixAmbushAnswer
	    /ambush (active) ->  ixAmbushAsk   ->  window  ->  ixAmbushAnswer (end)

	See `sh_ambush.lua` for the rules and `cl_ambush.lua` for the window.
]]

if (not SERVER) then return end

util.AddNetworkString("ixAmbushAsk")
util.AddNetworkString("ixAmbushAnswer")
util.AddNetworkString("ixAmbushState")
util.AddNetworkString("ixAmbushNotice")

--[[
	Tell everybody what is running.

	The whole table rather than a change, because there are at most a handful
	of factions ambushing at once and a client that joins mid-ambush needs the
	same message a client that was here for the start got.
]]
function ix.ambush.Sync(client)
	net.Start("ixAmbushState")
		net.WriteUInt(table.Count(ix.ambush.active), 8)

		for faction, entry in pairs(ix.ambush.active) do
			net.WriteUInt(faction, 8)
			net.WriteFloat(entry.endTime)
		end

	if (IsValid(client)) then
		net.Send(client)
	else
		net.Broadcast()
	end
end

--- Everybody in one faction, as a list. Used for the notices and the HUD.
local function Members(faction)
	local out = {}

	for _, client in player.Iterator() do
		local character = client:GetCharacter()

		if (character and character:GetFaction() == faction) then
			out[#out + 1] = client
		end
	end

	return out
end

--[[
	Start one.

	The cooldown starts NOW rather than when the ambush ends, so the config
	reads as "how often" rather than "how long afterwards" - and a faction that
	ends an ambush early is not rewarded with an earlier next one.
]]
function ix.ambush.Start(client, faction)
	local duration = ix.config.Get("ambushDuration", 300)

	ix.ambush.active[faction] = {
		endTime = CurTime() + duration,
		caller = IsValid(client) and client:SteamID() or "server",
		startedAt = CurTime()
	}

	ix.ambush.cooldowns[faction] = CurTime()
		+ math.max(ix.config.Get("ambushCooldown", 900), duration)

	ix.ambush.Sync()

	--[[
		THE GUNFIRE IS EVERYBODY'S, the countdown is the faction's.

		Phoenix send the announce to the whole server and the timer only to the
		people it applies to, which is the right split: an ambush is meant to
		be heard from a distance by people who do not know who is fighting.
	]]
	local data = ix.faction.indices[faction]

	ix.log.Add(client, "ambushStart", data and data.name or faction)

	--[[
		The line in chat is LATE - see `ambushNoticeDelay`. The sound goes out
		with it rather than at the start, so the two arrive together and the
		wasteland hears one event.
	]]
	local delay = ix.config.Get("ambushNoticeDelay", 25)

	timer.Simple(delay, function()
		if (not ix.ambush.IsActive(faction)) then return end

		net.Start("ixAmbushNotice")
			net.WriteUInt(math.random(#ix.ambush.notices), 4)
		net.Broadcast()
	end)
end

--[[
	End one. `bEarly` is the faction choosing to stop rather than the clock.
]]
function ix.ambush.Stop(faction, bEarly)
	if (not ix.ambush.active[faction]) then return end

	ix.ambush.active[faction] = nil
	ix.ambush.Sync()

	local data = ix.faction.indices[faction]

	for _, client in ipairs(Members(faction)) do
		client:Notify(bEarly and "Your faction's ambush has been called off."
			or "Your faction's ambush is over.")
	end

	ix.log.Add(nil, "ambushEnd", data and data.name or faction,
		bEarly and "early" or "on time")
end

--[[
	The clock. One timer for every ambush rather than one each, for the same
	reason the lock sweep is one timer: there are never many, and a table of
	timers keyed by faction is a table of timers to clean up.
]]
timer.Create("ixAmbush", 1, 0, function()
	for faction, entry in pairs(ix.ambush.active) do
		if (entry.endTime <= CurTime()) then
			ix.ambush.Stop(faction, false)
		end
	end
end)

--[[
	The answer to the confirmation.

	RE-CHECKED HERE. The window asked because the server told it to, but the
	rules are asked again on the way back - the time between the question and
	the answer is time in which the cooldown, the class or the faction can all
	have changed.
]]
net.Receive("ixAmbushAnswer", function(length, client)
	local bEnd = net.ReadBool()
	local character = client:GetCharacter()

	if (not character) then return end

	local faction = character:GetFaction()

	if (bEnd) then
		if (not ix.ambush.IsActive(faction)) then return end

		--[[
			ENDING IS THE SAME RANK AS STARTING. Anybody who could have called
			it can call it off, which matters when the person who started it
			has logged off mid-fight.
		]]
		local can, reason = ix.ambush.CanCall(client)

		if (not can and reason ~= "Your faction is already ambushing.") then
			client:Notify(reason)

			return
		end

		ix.ambush.Stop(faction, true)
		ix.log.Add(client, "ambushCancel")

		return
	end

	local can, reason = ix.ambush.CanCall(client)

	if (not can) then
		client:Notify(reason)

		return
	end

	ix.ambush.Start(client, faction)
end)

ix.command.Add("Ambush", {
	description = "Call an ambush for your faction, or end the one running.",

	OnRun = function(self, client)
		local character = client:GetCharacter()

		if (not character) then return "@noChar" end

		local faction = character:GetFaction()

		--[[
			ALREADY RUNNING: the same command offers to end it. One command
			rather than two because it is one decision - "is my faction
			fighting" - and the window says which way it is about to go.
		]]
		if (ix.ambush.IsActive(faction)) then
			net.Start("ixAmbushAsk")
				net.WriteBool(true)
				net.WriteUInt(math.ceil(ix.ambush.TimeLeft(faction)), 16)
			net.Send(client)

			return
		end

		local can, reason = ix.ambush.CanCall(client)

		if (not can) then return reason end

		net.Start("ixAmbushAsk")
			net.WriteBool(false)
			net.WriteUInt(ix.config.Get("ambushDuration", 300), 16)
		net.Send(client)
	end
})

--[[
	Admin housekeeping. Ending somebody else's ambush is a moderation action
	and is logged as one.
]]
ix.command.Add("AmbushEnd", {
	description = "End every ambush that is running.",
	adminOnly = true,

	OnRun = function(self, client)
		local count = 0

		for faction in pairs(table.Copy(ix.ambush.active)) do
			ix.ambush.Stop(faction, true)
			count = count + 1
		end

		return string.format("Ended %d ambush(es).", count)
	end
})

--[[
	The ambush half on its own, for when that is all somebody means.

	`/cooldownclear` in `sv_raid.lua` clears this as well as the conflict and
	shield ones - that is the command for "let them fight again". This is the
	narrow one, and it takes a faction.
]]
ix.command.Add("AmbushCooldownClear", {
	description = "Clear a faction's ambush cooldown. No faction clears "
		.. "everybody.",
	adminOnly = true,
	arguments = {bit.bor(ix.type.string, ix.type.optional)},

	OnRun = function(self, client, name)
		if (not name or name == "") then
			ix.ambush.cooldowns = {}

			return "Ambush cooldowns cleared."
		end

		for _, data in ipairs(ix.faction.indices) do
			if (ix.util.StringMatches(data.name, name)
			or ix.util.StringMatches(data.uniqueID, name)) then
				ix.ambush.cooldowns[data.index] = nil

				return string.format("%s may ambush again.", data.name)
			end
		end

		return "No faction by that name."
	end
})

--- A client that joins mid-ambush needs the countdown as much as anybody.
hook.Add("PlayerLoadedCharacter", "ixAmbush", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then ix.ambush.Sync(client) end
	end)
end)

ix.log.AddType("ambushStart", function(client, faction)
	return string.format("%s called an ambush for %s.",
		IsValid(client) and client:Name() or "the server", faction)
end, FLAG_WARNING)

ix.log.AddType("ambushEnd", function(client, faction, how)
	return string.format("%s's ambush ended (%s).", faction, how)
end)

ix.log.AddType("ambushCancel", function(client)
	return string.format("%s called off their faction's ambush.", client:Name())
end)
