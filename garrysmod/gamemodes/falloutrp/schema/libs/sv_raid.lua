--[[
	Raids, server side: starting one, ending one, and counting the dead.

	See `sh_raid.lua` for the rules. This owns the conflict itself - there is
	one, it is `ix.raid.current`, and every message here checks the rules again
	before touching it.

	THE STATISTICS ARE KILLS AND DEATHS, per faction and per person, and they
	are recorded as the conflict happens rather than counted afterwards: a
	player who disconnects mid-raid still fought in it, and their kills still
	belong to their faction.
]]

if (not SERVER) then return end

util.AddNetworkString("ixRaidState")
util.AddNetworkString("ixRaidCall")
util.AddNetworkString("ixRaidJoin")
util.AddNetworkString("ixRaidStats")
util.AddNetworkString("ixRaidOpenStats")
util.AddNetworkString("ixRaidAnnounce")
util.AddNetworkString("ixRaidCancel")

local COOLDOWN_KEY = "raidcooldowns"
local STATS_KEY = "raidstats"

--------------------------------------------------------------------------------
-- Persistence
--------------------------------------------------------------------------------

--[[
	COOLDOWNS AND SHIELDS SURVIVE A RESTART, and they have to.

	A faction that has just been raided would otherwise be raidable again the
	moment the server came back, which turns a restart into a weapon. They are
	stored as SECONDS REMAINING rather than as CurTime values, because CurTime
	restarts with the map and a stored 4000 would be either the past or the
	future depending on how long the server had been up.
]]
function ix.raid.Save()
	local remaining = {cooldowns = {}, shields = {}, shieldCooldowns = {}}

	for _, name in ipairs({"cooldowns", "shields", "shieldCooldowns"}) do
		for faction, expires in pairs(ix.raid[name]) do
			local left = expires - CurTime()

			if (left > 0) then remaining[name][faction] = left end
		end
	end

	ix.data.Set(COOLDOWN_KEY, remaining, false, true)
	ix.data.Set(STATS_KEY, ix.raid.lastStats, false, true)
end

function ix.raid.Load()
	local stored = ix.data.Get(COOLDOWN_KEY, {}, false, true) or {}

	for _, name in ipairs({"cooldowns", "shields", "shieldCooldowns"}) do
		ix.raid[name] = {}

		for faction, left in pairs(stored[name] or {}) do
			ix.raid[name][tonumber(faction)] = CurTime() + left
		end
	end

	ix.raid.lastStats = ix.data.Get(STATS_KEY, nil, false, true)
end

hook.Add("LoadData", "ixRaid", ix.raid.Load)
hook.Add("PostLoadData", "ixRaid", ix.raid.Load)

hook.Add("SaveData", "ixRaid", function()
	ix.raid.Save()
end)

--------------------------------------------------------------------------------
-- Telling everybody
--------------------------------------------------------------------------------

--[[
	The whole conflict, as a table.

	`net.WriteTable` for the same reason the live editor uses it: this is a
	small nested structure of mixed types that changes rarely, and a
	field-by-field message would be a second definition of its shape.
]]
function ix.raid.Sync(client)
	net.Start("ixRaidState")
		net.WriteBool(ix.raid.disabled)
		net.WriteTable(ix.raid.current or {})
		net.WriteTable(ix.raid.cooldowns)
		net.WriteTable(ix.raid.shields)

	if (IsValid(client)) then
		net.Send(client)
	else
		net.Broadcast()
	end
end

--- Everybody in one faction. Used for the announcements.
local function Members(faction)
	local out = {}

	for _, client in player.Iterator() do
		if (ix.raid.FactionOf(client) == faction) then out[#out + 1] = client end
	end

	return out
end

--[[
	Say something to the whole server, in the conflict's colour.

	One function so every announcement reads the same way, and so the sound
	that goes with it is chosen in one place.
]]
function ix.raid.Announce(text, sound)
	net.Start("ixRaidAnnounce")
		net.WriteString(text)
		net.WriteString(sound or "")
	net.Broadcast()
end

--------------------------------------------------------------------------------
-- Starting and ending
--------------------------------------------------------------------------------

--[[
	The empty scoreline for one faction. Made when a faction joins rather than
	at the end, so a faction that fought and scored nothing still appears in
	`/raidstats` - "they turned up and lost" is a result.
]]
local function Score()
	return {kills = 0, deaths = 0, players = {}}
end

function ix.raid.Start(typeID, attacker, defender, caller)
	local info = ix.raid.types[typeID]

	if (not info) then return false, "No such kind of conflict." end

	local duration = ix.config.Get(typeID .. "Time", 900)

	ix.raid.current = {
		type = typeID,
		attacker = attacker,
		defender = defender,
		attackers = {},
		defenders = {},
		skirmishers = {},
		startTime = CurTime(),
		endTime = CurTime() + duration,
		kills = {[attacker] = Score(), [defender] = Score()}
	}

	ix.raid.Sync()

	local attackerData = ix.faction.indices[attacker]
	local defenderData = ix.faction.indices[defender]

	ix.raid.Announce(string.format("%s has called %s on %s.",
		attackerData.name, info.name, defenderData.name),
		string.format("phoenix/amb/mus_bttl_in_rural_%02d.mp3", math.random(4)))

	ix.log.Add(caller, "raidStart", info.name, attackerData.name,
		defenderData.name)

	return true
end

--[[
	End it, put everybody on cooldown, and keep the scoreline.

	EVERY FACTION THAT TOOK PART goes on cooldown, not just the two principals
	- assisting is taking part, and a faction that could assist every raid on
	the map without ever going on cooldown would be in all of them.
]]
function ix.raid.Stop(bForced)
	local raid = ix.raid.current

	if (not raid) then return end

	local info = ix.raid.types[raid.type]
	local cooldown = ix.config.Get(raid.type .. "Cooldown", 1800)

	local involved = {[raid.attacker] = true, [raid.defender] = true}

	for _, side in ipairs({"attackers", "defenders", "skirmishers"}) do
		for faction in pairs(raid[side]) do involved[faction] = true end
	end

	for faction in pairs(involved) do
		ix.raid.cooldowns[faction] = CurTime() + cooldown
	end

	--[[
		THE SCORELINE OUTLIVES THE CONFLICT, which is the whole point of
		`/raidstats`: the argument about who won happens afterwards.
	]]
	ix.raid.lastStats = {
		type = raid.type,
		attacker = raid.attacker,
		defender = raid.defender,
		attackers = raid.attackers,
		defenders = raid.defenders,
		skirmishers = raid.skirmishers,
		kills = raid.kills,
		startTime = raid.startTime,
		endTime = CurTime(),
		forced = bForced == true
	}

	ix.raid.current = nil
	ix.raid.Save()
	ix.raid.Sync()

	ix.raid.Announce(string.format("%s between %s and %s has ended.%s",
		info and info.name or "The conflict",
		ix.faction.indices[raid.attacker].name,
		ix.faction.indices[raid.defender].name,
		bForced and " (called off)" or " Type /raidstats to see how it went."),
		string.format("phoenix/amb/mus_bttl_out_rural_%02d.mp3", math.random(6)))

	--[[
		THE REPORT IS KEPT, NOT SHOWN.

		It used to open itself on everybody's screen when a conflict ended,
		which is a window appearing over whatever somebody was doing - and the
		fight ending is exactly the moment people are still shooting. The
		announcement says it is there; `/raidstats` is how it is read.
	]]
	ix.raid.Announce("Type /raidstats for the report.")

	ix.log.Add(nil, "raidEnd", info and info.name or raid.type,
		bForced and "forced" or "ran out")
end

--- The clock, and the warning before it runs out.
timer.Create("ixRaid", 1, 0, function()
	local raid = ix.raid.current

	if (not raid) then return end

	if (CurTime() >= raid.endTime) then
		ix.raid.Stop(false)

		return
	end

	--[[
		A minute's warning, once. `warned` is on the conflict rather than in a
		local so it cannot survive into the next one.
	]]
	if (not raid.warned and raid.endTime - CurTime() <= 60) then
		raid.warned = true

		ix.raid.Announce("One minute of fighting left.")
	end
end)

--------------------------------------------------------------------------------
-- Kills
--------------------------------------------------------------------------------

--[[
	Who killed whom, while a conflict is running.

	BOTH SIDES OF EVERY DEATH ARE RECORDED - a death is a fact about the person
	who died and about whoever did it, and a k/d that counted only kills would
	make the faction that never turned up look perfect.

	People are keyed by STEAM ID rather than by character, because the argument
	afterwards is about who was there, and a player who switched characters
	mid-raid is still the same person.
]]
hook.Add("PlayerDeath", "ixRaid", function(victim, inflictor, attacker)
	local raid = ix.raid.current

	if (not raid) then return end

	--- One helper, because both halves of a death are the same three lines.
	local function Record(faction, client, field)
		local score = raid.kills[faction]

		if (not score) then return end

		score[field] = (score[field] or 0) + 1

		local id = client:SteamID()

		score.players[id] = score.players[id]
			or {name = client:Name(), kills = 0, deaths = 0}
		score.players[id][field] = score.players[id][field] + 1
		score.players[id].name = client:Name()
	end

	--[[
		A DEATH IS A DEATH, however it happened.

		Falling off a roof mid-raid, drowning, or being shot by your own side
		all count against the faction that lost the body - because they all
		cost that faction the same thing, and a scoreline that only counted
		deaths with a tidy enemy attacker would flatter whoever died carelessly
		rather than whoever died fighting.

		The only requirement is that the DEAD were in the conflict. A
		wastelander who wanders into a firefight is not part of the scoreline
		either way.
	]]
	local victimFaction = ix.raid.FactionOf(victim)
	local victimSide = ix.raid.Side(victimFaction)

	if (not victimSide) then return end

	Record(victimFaction, victim, "deaths")

	--[[
		A KILL IS NARROWER, and deliberately so.

		It needs a real player, on a side, on a DIFFERENT side. Shooting a
		bystander is not a raid kill - counting it would make the scoreline a
		measure of who found more bystanders - and neither is shooting your own
		man: the death above already costs your faction, and paying a kill for
		it as well would make team-killing a way to inflate somebody's ratio.
	]]
	if (not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim) then
		return
	end

	local killerFaction = ix.raid.FactionOf(attacker)
	local killerSide = ix.raid.Side(killerFaction)

	if (not killerSide or killerSide == victimSide) then return end

	Record(killerFaction, attacker, "kills")
end)

--------------------------------------------------------------------------------
-- The buttons
--------------------------------------------------------------------------------

--[[
	"Call this on that faction."

	The window asked for confirmation before sending this; the server does not
	care that it did, and checks everything again.
]]
net.Receive("ixRaidCall", function(length, client)
	local typeID = net.ReadString()
	local faction = net.ReadUInt(8)

	local can, reason = ix.raid.CanCall(client, typeID, faction)

	if (not can) then
		client:Notify(reason)

		return
	end

	ix.raid.Start(typeID, ix.raid.FactionOf(client), faction, client)
end)

--[[
	"Join the one that is running", on one of the three sides.
]]
net.Receive("ixRaidJoin", function(length, client)
	local side = net.ReadString()

	if (side ~= "attackers" and side ~= "defenders"
	and side ~= "skirmishers") then
		return
	end

	local can, reason = ix.raid.CanJoin(client, side)

	if (not can) then
		client:Notify(reason)

		return
	end

	local raid = ix.raid.current
	local faction = ix.raid.FactionOf(client)

	raid[side][faction] = true
	raid.kills[faction] = raid.kills[faction] or {kills = 0, deaths = 0,
		players = {}}

	ix.raid.Sync()

	local data = ix.faction.indices[faction]

	ix.raid.Announce(string.format("%s has joined the fighting as %s.",
		data.name, side == "skirmishers" and "a third party"
			or (side == "attackers" and "an attacker" or "a defender")))

	ix.log.Add(client, "raidJoin", data.name, side)
end)

--[[
	The attacking faction calling off its own conflict.

	NCO AND ABOVE, and only the ATTACKER - the same rank that could have
	called it. The people being raided do not get this button: "call off the
	raid on us" is a surrender that costs the other faction their fight, and
	it is not theirs to decide.

	The cooldown still applies. Calling one off to dodge the cooldown would
	make the cooldown optional.
]]
net.Receive("ixRaidCancel", function(length, client)
	local raid = ix.raid.current

	if (not raid) then return end

	local faction = ix.raid.FactionOf(client)

	if (raid.attacker ~= faction) then
		client:Notify("Only the faction that called it can call it off.")

		return
	end

	local rank = ix.factionmgmt and ix.factionmgmt.GetRank(client) or 0

	if (rank < 2) then
		client:Notify("You must be an NCO or above.")

		return
	end

	ix.raid.Announce(string.format("%s has called off the fighting.",
		ix.faction.indices[faction].name))

	ix.log.Add(client, "raidCallOff", ix.faction.indices[faction].name)

	ix.raid.Stop(true)
end)

net.Receive("ixRaidOpenStats", function(length, client)
	net.Start("ixRaidStats")
		net.WriteTable(ix.raid.lastStats or {})
	net.Send(client)
end)

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

ix.command.Add("RaidStats", {
	description = "Show how the last conflict went.",

	OnRun = function(self, client)
		if (not ix.raid.lastStats) then
			return "Nothing has been fought yet."
		end

		net.Start("ixRaidStats")
			net.WriteTable(ix.raid.lastStats)
		net.Send(client)
	end
})

ix.command.Add("RaidShield", {
	description = "Raise a raid shield over your faction.",

	OnRun = function(self, client)
		local can, reason = ix.raid.CanShield(client)

		if (not can) then return reason end

		local faction = ix.raid.FactionOf(client)
		local duration = ix.config.Get("raidShieldDuration", 3600)

		ix.raid.shields[faction] = CurTime() + duration
		ix.raid.shieldCooldowns[faction] = CurTime()
			+ math.max(ix.config.Get("raidShieldCooldown", 7200), duration)

		ix.raid.Save()
		ix.raid.Sync()

		for _, member in ipairs(Members(faction)) do
			member:Notify(string.format("A raid shield is up for %d minutes.",
				math.floor(duration / 60)))
		end

		ix.log.Add(client, "raidShield",
			ix.faction.indices[faction].name, duration)

		return "Raid shield raised."
	end
})

ix.command.Add("CancelRaidShield", {
	description = "Drop your faction's raid shield early.",

	OnRun = function(self, client)
		local faction = ix.raid.FactionOf(client)

		if (not ix.raid.Shielded(faction)) then
			return "Your faction has no shield up."
		end

		local rank = ix.factionmgmt and ix.factionmgmt.GetRank(client) or 0

		if (rank < ix.config.Get("raidShieldRank", 3)) then
			return "You are not senior enough to drop it."
		end

		ix.raid.shields[faction] = nil
		ix.raid.Save()
		ix.raid.Sync()

		--[[
			THE COOLDOWN IS NOT REFUNDED. Dropping a shield early is a choice;
			letting it be dropped and re-raised at will would make the cooldown
			meaningless.
		]]
		for _, member in ipairs(Members(faction)) do
			member:Notify("The raid shield has been dropped.")
		end

		ix.log.Add(client, "raidShieldCancel",
			ix.faction.indices[faction].name)

		return "Raid shield dropped."
	end
})

--------------------------------------------------------------------------------
-- Admin
--------------------------------------------------------------------------------

ix.command.Add("RaidStop", {
	description = "End the conflict in progress.",
	adminOnly = true,

	OnRun = function(self, client)
		if (not ix.raid.InProgress()) then return "Nothing is running." end

		ix.raid.Stop(true)
		ix.log.Add(client, "raidForceEnd")

		return "Conflict ended."
	end
})

--[[
	`/stopattack` - the name an admin will reach for.

	The same thing `/raidstop` does. Two names for one action is normally a
	smell, but this is the word people use in the middle of an event and the
	alternative is somebody typing the wrong one while a fight they need to
	stop carries on.
]]
ix.command.Add("StopAttack", {
	description = "End the raid, hostilities or war in progress.",
	adminOnly = true,

	OnRun = function(self, client)
		if (not ix.raid.InProgress()) then return "Nothing is running." end

		local raid = ix.raid.current
		local info = ix.raid.types[raid.type]

		ix.raid.Announce(string.format("%s has been stopped by staff.",
			info and info.name or "The conflict"))

		ix.raid.Stop(true)
		ix.log.Add(client, "raidForceEnd")

		return "Stopped."
	end
})

ix.command.Add("RaidsToggle", {
	description = "Switch raids on or off for everybody.",
	adminOnly = true,

	OnRun = function(self, client)
		ix.raid.disabled = not ix.raid.disabled

		ix.raid.Sync()
		ix.log.Add(client, "raidToggle", ix.raid.disabled)

		return ix.raid.disabled and "Raids are OFF." or "Raids are on."
	end
})

--[[
	Put a faction on a side, whatever the rules say.

	FOR TESTING, and it says so: there is no way to see what a skirmish looks
	like without a third faction with somebody in it, which on a quiet server
	is a thing an admin cannot arrange. It takes the same three side names the
	rest of the system uses.
]]
ix.command.Add("RaidForceSide", {
	description = "Put a faction into the running conflict on a side: "
		.. "attackers, defenders or skirmishers.",
	adminOnly = true,
	arguments = {ix.type.string, ix.type.string},

	OnRun = function(self, client, name, side)
		local raid = ix.raid.current

		if (not raid) then return "Nothing is running." end

		side = string.lower(side or "")

		if (side ~= "attackers" and side ~= "defenders"
		and side ~= "skirmishers") then
			return "Side must be attackers, defenders or skirmishers."
		end

		local target

		for _, data in ipairs(ix.faction.indices) do
			if (ix.util.StringMatches(data.name, name)
			or ix.util.StringMatches(data.uniqueID, name)) then
				target = data

				break
			end
		end

		if (not target) then return "No faction by that name." end

		if (ix.raid.Side(target.index)) then
			return string.format("%s is already in it.", target.name)
		end

		raid[side][target.index] = true
		raid.kills[target.index] = raid.kills[target.index]
			or {kills = 0, deaths = 0, players = {}}

		ix.raid.Sync()

		ix.raid.Announce(string.format("%s has joined the fighting as %s.",
			target.name, side == "skirmishers" and "a third party"
				or (side == "attackers" and "an attacker" or "a defender")))

		ix.log.Add(client, "raidForceSide", target.name, side)

		return string.format("%s is now on the %s.", target.name, side)
	end
})

--[[
	The same thing with nothing to type, for when the question is only "what
	does a skirmish look like". Picks a faction that is free to join one.
]]
ix.command.Add("RaidTestSkirmish", {
	description = "Drop a random uninvolved faction in as a skirmisher.",
	adminOnly = true,

	OnRun = function(self, client)
		local raid = ix.raid.current

		if (not raid) then return "Nothing is running." end

		local choices = {}

		for _, data in ipairs(ix.faction.indices) do
			if (data.isDefault or ix.raid.Side(data.index)
			or ix.faction.RaidImmune(data.index)) then
				continue
			end

			choices[#choices + 1] = data
		end

		if (#choices == 0) then return "Every faction is already in it." end

		local target = choices[math.random(#choices)]

		raid.skirmishers[target.index] = true
		raid.kills[target.index] = raid.kills[target.index]
			or {kills = 0, deaths = 0, players = {}}

		ix.raid.Sync()

		ix.raid.Announce(string.format("%s has joined the fighting as a third "
			.. "party.", target.name))

		ix.log.Add(client, "raidForceSide", target.name, "skirmishers")

		return string.format("%s is skirmishing.", target.name)
	end
})

--- One faction by name or id, or nil. The lookup three commands here share.
local function FindFaction(name)
	if (not name or name == "") then return nil end

	for _, data in ipairs(ix.faction.indices) do
		if (ix.util.StringMatches(data.name, name)
		or ix.util.StringMatches(data.uniqueID, name)) then
			return data
		end
	end
end

--[[
	Clear what is stopping a faction fighting.

	ONE COMMAND FOR ALL THREE COOLDOWNS, because "clear their cooldowns" is one
	thought and remembering which of them a war used is not. A war IS a raid
	here - `sv_raid.lua` puts every conflict's cooldown in the same table
	keyed by faction - so `/warcooldownclear` and `/raidcooldownclear` are the
	same command under two names people will reach for.

	    conflict cooldown    after any raid, hostilities or war
	    shield cooldown      how soon another raid shield may go up
	    ambush cooldown      how soon the faction may ambush again

	AN ACTIVE RAID SHIELD IS NOT DROPPED. That is a thing a faction chose and
	paid for, not a cooldown - `/raidshieldset <faction> 0` removes one, and
	the reply says so rather than leaving somebody wondering why the shield is
	still up.

	No argument clears every faction, which is the event-night case.
]]
ix.command.Add("CooldownClear", {
	description = "Clear a faction's raid, war, shield and ambush cooldowns. "
		.. "No faction clears everybody.",
	adminOnly = true,
	alias = {"RaidCooldownClear", "WarCooldownClear", "ClearCooldowns"},
	arguments = {bit.bor(ix.type.string, ix.type.optional)},

	OnRun = function(self, client, name)
		local target = FindFaction(name)

		if (name and name ~= "" and not target) then
			return "No faction by that name."
		end

		if (target) then
			ix.raid.cooldowns[target.index] = nil
			ix.raid.shieldCooldowns[target.index] = nil

			if (ix.ambush) then
				ix.ambush.cooldowns[target.index] = nil
			end
		else
			ix.raid.cooldowns = {}
			ix.raid.shieldCooldowns = {}

			if (ix.ambush) then
				ix.ambush.cooldowns = {}
			end
		end

		ix.raid.Save()
		ix.raid.Sync()

		if (ix.ambush and ix.ambush.Sync) then
			ix.ambush.Sync()
		end

		ix.log.Add(client, "raidCooldownClear",
			target and target.name or "every faction")

		return string.format("Cleared %s cooldowns - raid, war, shield and "
			.. "ambush.%s", target and (target.name .. "'s") or "everybody's",
			target and ix.raid.Shielded(target.index)
				and " Their raid shield is still up: /raidshieldset "
					.. target.uniqueID .. " 0 removes it."
				or "")
	end
})

--[[
	WHAT IS ON WHAT, which is the question the clear command is usually being
	asked in the middle of: somebody says they cannot raid and the answer is
	one of four different timers.

	Only factions with something running are listed. A page of forty-five
	"nothing" rows is a page nobody reads to the bottom of.
]]
ix.command.Add("Cooldowns", {
	description = "List which factions are on cooldown, shielded, or "
		.. "ambushing.",
	adminOnly = true,

	OnRun = function(self, client)
		local lines = {}

		local function Time(seconds)
			seconds = math.ceil(seconds)

			if (seconds < 60) then return seconds .. "s" end

			return string.format("%dm %ds", math.floor(seconds / 60),
				seconds % 60)
		end

		for _, data in ipairs(ix.faction.indices) do
			local parts = {}
			local index = data.index

			local conflict = ix.raid.TimeLeft(ix.raid.cooldowns, index)
			local shield = ix.raid.TimeLeft(ix.raid.shields, index)
			local shieldWait = ix.raid.TimeLeft(ix.raid.shieldCooldowns, index)

			if (conflict > 0) then
				parts[#parts + 1] = "conflict " .. Time(conflict)
			end

			if (shield > 0) then
				parts[#parts + 1] = "SHIELDED " .. Time(shield)
			end

			if (shieldWait > 0) then
				parts[#parts + 1] = "next shield " .. Time(shieldWait)
			end

			if (ix.ambush) then
				local ambush = ix.ambush.Cooldown(index)

				if (ix.ambush.IsActive(index)) then
					parts[#parts + 1] = "AMBUSHING "
						.. Time(ix.ambush.TimeLeft(index))
				elseif (ambush > 0) then
					parts[#parts + 1] = "ambush " .. Time(ambush)
				end
			end

			if (#parts > 0) then
				lines[#lines + 1] = string.format("%s: %s", data.name,
					table.concat(parts, ", "))
			end
		end

		if (#lines == 0) then
			return "Nothing is on cooldown and nothing is shielded."
		end

		for _, line in ipairs(lines) do
			client:ChatPrint(line)
		end
	end
})

--[[
	FORCING A SHIELD ON OR OFF, which is the admin half of the shield system -
	an event needs a faction that cannot be raided for an hour, and a faction
	that has been sitting behind a shield to avoid a fight needs it taken off.
]]
ix.command.Add("RaidShieldSet", {
	description = "Force a raid shield onto a faction for a number of "
		.. "minutes. 0 removes it.",
	adminOnly = true,
	arguments = {ix.type.string, ix.type.number},

	OnRun = function(self, client, name, minutes)
		local faction = ix.faction.teams[string.lower(name)]

		if (not faction) then
			for _, data in ipairs(ix.faction.indices) do
				if (ix.util.StringMatches(data.name, name)) then
					faction = data

					break
				end
			end
		end

		if (not faction) then return "No faction by that name." end

		minutes = math.Clamp(math.floor(minutes or 0), 0, 10080)

		if (minutes <= 0) then
			ix.raid.shields[faction.index] = nil
		else
			ix.raid.shields[faction.index] = CurTime() + minutes * 60
		end

		ix.raid.Save()
		ix.raid.Sync()

		ix.log.Add(client, "raidShieldForce", faction.name, minutes)

		return minutes > 0
			and string.format("%s is shielded for %d minutes.", faction.name,
				minutes)
			or string.format("%s's shield removed.", faction.name)
	end
})

hook.Add("PlayerLoadedCharacter", "ixRaid", function(client)
	timer.Simple(1, function()
		if (IsValid(client)) then ix.raid.Sync(client) end
	end)
end)

ix.log.AddType("raidStart", function(client, kind, attacker, defender)
	return string.format("%s called %s: %s on %s.",
		IsValid(client) and client:Name() or "the server", kind, attacker,
		defender)
end, FLAG_WARNING)

ix.log.AddType("raidEnd", function(client, kind, how)
	return string.format("%s ended (%s).", kind, how)
end)

ix.log.AddType("raidJoin", function(client, faction, side)
	return string.format("%s brought %s in as %s.", client:Name(), faction,
		side)
end)

ix.log.AddType("raidShield", function(client, faction, duration)
	return string.format("%s raised a raid shield over %s for %d seconds.",
		client:Name(), faction, duration)
end)

ix.log.AddType("raidShieldCancel", function(client, faction)
	return string.format("%s dropped %s's raid shield.", client:Name(), faction)
end)

ix.log.AddType("raidShieldForce", function(client, faction, minutes)
	return string.format("%s set %s's raid shield to %d minutes.",
		client:Name(), faction, minutes)
end, FLAG_DANGER)

ix.log.AddType("raidCooldownClear", function(client, who)
	return string.format("%s cleared %s cooldowns.", client:Name(), who)
end, FLAG_DANGER)

ix.log.AddType("raidForceSide", function(client, faction, side)
	return string.format("%s put %s into the conflict as %s.", client:Name(),
		faction, side)
end, FLAG_DANGER)

ix.log.AddType("raidCallOff", function(client, faction)
	return string.format("%s called off %s's conflict.", client:Name(), faction)
end)

ix.log.AddType("raidForceEnd", function(client)
	return string.format("%s ended the conflict early.", client:Name())
end, FLAG_DANGER)

ix.log.AddType("raidToggle", function(client, disabled)
	return string.format("%s turned raids %s.", client:Name(),
		disabled and "OFF" or "on")
end, FLAG_DANGER)
