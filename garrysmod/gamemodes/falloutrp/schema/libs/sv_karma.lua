--[[
	Karma, server side: earning it, storing it, and telling everybody.

	See `sh_karma.lua` for what karma IS and where the numbers come from. This
	is the timer, the kill hook, the two saves and the networking.

	TWO SAVES, and they are different kinds of thing:

	    the character's    item data on the character, saved with it
	    the faction's      one table for the whole server, in `ix.data`

	A faction's karma is the sum of what its members have earned WHILE IN IT,
	accumulated as it happens rather than recomputed - somebody who leaves does
	not take the faction's history with them, which is the point of a faction
	having a reputation at all.
]]

if (not SERVER) then return end

util.AddNetworkString("ixKarmaFactions")
util.AddNetworkString("ixKarmaSettings")
util.AddNetworkString("ixKarmaSet")

ix.karma = ix.karma or {}

local KARMA_KEY = "karma"
local SETTINGS_KEY = "karmasettings"
local loaded = false

--------------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------------

function ix.karma.Save()
	if (not loaded) then return end

	ix.data.Set(KARMA_KEY, ix.karma.factions, false, true)
	ix.data.Set(SETTINGS_KEY, ix.karma.settings, false, true)
end

function ix.karma.Load()
	if (loaded) then return end

	ix.karma.factions = ix.data.Get(KARMA_KEY, {}, false, true) or {}
	ix.karma.settings = ix.data.Get(SETTINGS_KEY, {}, false, true) or {}
	loaded = true

	--[[
		SEEDED FROM THE FACTION FILES ONCE, if they carry Phoenix's own
		`FACTION.karma`. Ours are generated and do not, so in practice this
		does nothing here - but a faction written by hand with the field on it
		should be honoured rather than silently ignored, and after the first
		load the terminal owns the numbers.
	]]
	for _, faction in ipairs(ix.faction.indices) do
		if (ix.karma.settings[faction.uniqueID] or not faction.karma) then
			continue
		end

		ix.karma.settings[faction.uniqueID] = {
			passive = faction.karma.passive,
			kill = faction.karma.kill
		}
	end

	ix.karma.Save()
end

hook.Add("LoadData", "ixKarma", ix.karma.Load)
hook.Add("PostLoadData", "ixKarma", ix.karma.Load)
timer.Simple(10, ix.karma.Load)

hook.Add("SaveData", "ixKarma", function()
	ix.karma.Save()
end)

--------------------------------------------------------------------------------
-- Networking
--------------------------------------------------------------------------------

--[[
	Every faction's total, to one client or to everybody.

	Sent whole rather than per faction: there are forty of them and two numbers
	each, which is nothing, and a partial update is a thing that can go missing
	and leave one faction's bar wrong for the rest of the session.
]]
function ix.karma.Sync(client)
	local list = {}

	for uniqueID, karma in pairs(ix.karma.factions) do
		list[#list + 1] = {
			uniqueID = uniqueID,
			good = math.floor(tonumber(karma[1]) or 0),
			bad = math.floor(tonumber(karma[2]) or 0)
		}
	end

	net.Start("ixKarmaFactions")
		net.WriteUInt(#list, 8)

		for _, entry in ipairs(list) do
			net.WriteString(entry.uniqueID)
			net.WriteUInt(math.Clamp(entry.good, 0, 2000000000), 32)
			net.WriteUInt(math.Clamp(entry.bad, 0, 2000000000), 32)
		end

	if (IsValid(client)) then
		net.Send(client)
	else
		net.Broadcast()
	end
end

--- The per-faction settings, for the developer terminal to draw.
function ix.karma.SyncSettings(client)
	local list = {}

	for _, faction in ipairs(ix.faction.indices) do
		local settings = ix.karma.Settings(faction.uniqueID)

		list[#list + 1] = {uniqueID = faction.uniqueID, settings = settings}
	end

	net.Start("ixKarmaSettings")
		net.WriteUInt(#list, 8)

		for _, entry in ipairs(list) do
			net.WriteString(entry.uniqueID)
			net.WriteInt(entry.settings.passive[1], 16)
			net.WriteInt(entry.settings.passive[2], 16)
			net.WriteInt(entry.settings.kill[1], 16)
			net.WriteInt(entry.settings.kill[2], 16)
		end

	if (IsValid(client)) then
		net.Send(client)
	else
		net.Broadcast()
	end
end

--------------------------------------------------------------------------------
-- Earning it
--------------------------------------------------------------------------------

--[[
	Write a character's karma, and network it.

	`SetNetVar` on the PLAYER, because character data reaches its owner only
	and a title everybody can see has to reach everybody - see `ix.karma.Of`,
	which reads whichever of the two the realm has.
]]
local function Write(client, character, good, bad)
	good = math.max(math.floor(good), 0)
	bad = math.max(math.floor(bad), 0)

	character:SetData("karma", {good, bad})

	if (IsValid(client)) then
		client:SetNetVar("karma", {good, bad})
	end
end

--[[
	Give somebody karma, and give their faction the same.

	`good` and `bad` are both ADDED - a kill that is worth "+1 good, +5 bad"
	adds both, which is what makes somebody who kills a great deal a notorious
	figure rather than a neutral one. See the header of `sh_karma.lua`.
]]
function ix.karma.Add(client, good, bad, reason, bQuiet)
	if (not IsValid(client)) then return end
	if (not ix.config.Get("karmaEnabled", true)) then return end

	local character = client:GetCharacter()

	if (not character) then return end

	good = math.max(math.floor(good or 0), 0)
	bad = math.max(math.floor(bad or 0), 0)

	if (good == 0 and bad == 0) then return end

	local haveGood, haveBad = ix.karma.Of(character)

	Write(client, character, haveGood + good, haveBad + bad)

	--[[
		THE FACTION EARNS IT AT THE SAME MOMENT, and only while the character
		is IN that faction. Recomputing a faction's karma from its current
		members would erase everything anybody who ever left had done for it,
		which is the opposite of a reputation.
	]]
	local faction = ix.karma.FactionOf(character)

	if (faction and loaded) then
		local stored = ix.karma.factions[faction.uniqueID] or {0, 0}

		ix.karma.factions[faction.uniqueID] = {
			(tonumber(stored[1]) or 0) + good,
			(tonumber(stored[2]) or 0) + bad
		}
	end

	if (bQuiet or not ix.config.Get("karmaNotify", true)) then return end

	--[[
		THE SOUND AND NOTHING ELSE.

		There was a notice in the corner as well, and it was wrong: a kill
		already fills that corner with what the kill did, karma is a slow
		thing rather than an event, and a line reading "+1 good, +5 bad" turns
		a reputation into a scoreboard. The rising or falling tone says which
		way it went, which is all anybody needs in the moment - the number is
		in `/karma` and the title is under their name.

		Both at once is the common case for a kill, so the sound follows
		whichever half is LARGER rather than trying to play two.
	]]
	client:EmitSound(bad > good and "phoenix/ui/nv/ui_karma_down.mp3"
		or "phoenix/ui/nv/ui_karma_up.mp3", 55, 100, 0.5)
end

--------------------------------------------------------------------------------
-- Where it comes from
--------------------------------------------------------------------------------

--[[
	Passive karma, on the faction's own timer.

	ONE TIMER FOR EVERYBODY rather than one per player: the interval is the
	same for all of them, and a timer per player is forty timers that have to
	be created, adjusted and removed as people join, change faction and leave.

	Recreated when the interval changes, which is what the config callback in
	`ix.config.Add` would do if Helix passed one - it does not, so the tick
	checks the interval itself and rebuilds when it has moved.
]]
local interval = -1

local function Tick()
	if (not ix.config.Get("karmaEnabled", true)) then return end

	for _, client in player.Iterator() do
		local character = client:GetCharacter()

		if (not character) then continue end

		local faction = ix.karma.FactionOf(character)

		if (not faction) then continue end

		local settings = ix.karma.Settings(faction.uniqueID)

		--[[
			QUIET, which is what the last argument is for. Passive karma
			happens every minute for as long as somebody is online, and a
			notification every minute is a notification nobody reads - the
			title under their name is the feedback.
		]]
		ix.karma.Add(client, settings.passive[1], settings.passive[2], nil,
			true)
	end

	ix.karma.Save()
	ix.karma.Sync()
end

timer.Create("ixKarmaTick", 1, 0, function()
	local wanted = math.max(math.floor(ix.config.Get("karmaTimer", 60)), 10)

	if (interval ~= wanted) then
		interval = wanted

		timer.Create("ixKarmaPassive", wanted, 0, Tick)
	end
end)

--[[
	A kill gives the killer the VICTIM's faction's `kill` pair.

	So what a killing is worth is decided by who was killed, which is the whole
	idea: the Fiends are set up to be worth good karma to kill and the NCR to
	be worth bad. A faction's own numbers say how the wasteland feels about
	losing one of them.

	SUICIDE AND FRIENDLY FIRE ARE EXCLUDED. Killing yourself for karma is the
	first thing anybody would try, and killing your own faction pays out the
	pair meant for outsiders.
]]
hook.Add("PlayerDeath", "ixKarma", function(victim, inflictor, attacker)
	if (not ix.config.Get("karmaEnabled", true)) then return end
	if (not IsValid(attacker) or not attacker:IsPlayer()) then return end
	if (attacker == victim) then return end

	local theirs = victim:GetCharacter()
	local ours = attacker:GetCharacter()

	if (not theirs or not ours) then return end

	local faction = ix.karma.FactionOf(theirs)

	if (not faction) then return end
	if (theirs:GetFaction() == ours:GetFaction()) then return end

	local settings = ix.karma.Settings(faction.uniqueID)

	ix.karma.Add(attacker, settings.kill[1], settings.kill[2],
		"killed " .. faction.name)

	ix.karma.Save()
	ix.karma.Sync()
end)

--------------------------------------------------------------------------------
-- Joining
--------------------------------------------------------------------------------

--[[
	The netvar is written on load as well as on every change, because it lives
	on the PLAYER and a player who has just connected has none - their karma
	would read as zero to everybody looking at them until they next earned
	some.
]]
hook.Add("PlayerLoadedCharacter", "ixKarma", function(client, character)
	local good, bad = ix.karma.Of(character)

	client:SetNetVar("karma", {good, bad})

	timer.Simple(1, function()
		if (not IsValid(client)) then return end

		ix.karma.Sync(client)
		ix.karma.SyncSettings(client)
	end)
end)

--------------------------------------------------------------------------------
-- Setting it by hand
--------------------------------------------------------------------------------

--- Used by `/CharSetKarma` and by the developer terminal.
function ix.karma.Set(client, good, bad)
	if (not IsValid(client)) then return false end

	local character = client:GetCharacter()

	if (not character) then return false end

	Write(client, character, good, bad)

	return true
end

--[[
	Change what a faction hands out.

	Clamped rather than refused: the terminal sends what somebody typed, and a
	faction that pays a thousand karma a minute is a mistake worth preventing
	rather than a message worth arguing about.
]]
function ix.karma.SetSettings(uniqueID, passive, kill)
	if (not loaded) then return false end

	local function Clean(pair)
		return {
			math.Clamp(math.floor(tonumber(pair[1]) or 0), 0, 1000),
			math.Clamp(math.floor(tonumber(pair[2]) or 0), 0, 1000)
		}
	end

	ix.karma.settings[uniqueID] = {
		passive = Clean(passive),
		kill = Clean(kill)
	}

	ix.karma.Save()
	ix.karma.SyncSettings()

	return true
end

--[[
	The developer terminal changing what a faction hands out.

	ADMIN CHECKED HERE, not by the window: the terminal is a panel and a panel
	is not a permission (gotcha 15). Same check the rest of it uses.
]]
net.Receive("ixKarmaSet", function(length, client)
	if (not ix.admin.Can(client, "dev.terminal")) then
		ix.log.Add(client, "devTerminalDenied")

		return
	end

	local uniqueID = net.ReadString()
	local passive = {net.ReadInt(16), net.ReadInt(16)}
	local kill = {net.ReadInt(16), net.ReadInt(16)}

	--- A faction that exists, and nothing else.
	local faction = ix.faction.teams[uniqueID]

	if (not faction) then return end
	if (not ix.karma.SetSettings(uniqueID, passive, kill)) then return end

	local now = ix.karma.Settings(uniqueID)

	client:Notify(string.format("%s: passive +%d/+%d, kill +%d/+%d.",
		faction.name, now.passive[1], now.passive[2], now.kill[1],
		now.kill[2]))

	ix.log.Add(client, "karmaFaction", faction.name, now.passive[1],
		now.passive[2], now.kill[1], now.kill[2])
end)

ix.log.AddType("karmaSet", function(client, name, good, bad)
	return string.format("%s set %s's karma to %d good, %d bad.",
		client:Name(), name, good, bad)
end, FLAG_WARNING)

ix.log.AddType("karmaFaction", function(client, faction, passiveGood,
	passiveBad, killGood, killBad)
	return string.format("%s set %s karma to passive %d/%d, kill %d/%d.",
		client:Name(), faction, passiveGood, passiveBad, killGood, killBad)
end, FLAG_WARNING)
