--[[
	Raids, hostilities and wars - one conflict, three shapes.

	Phoenix's `raid` plugin is the reference and its central idea is worth
	keeping: there is ONE conflict at a time, it has a type, and the type
	decides who may call it, how long it runs, and whether anybody else may
	join in. Everything else is the same machinery.

	    HOSTILITIES   one faction against one. Nobody may join.
	    RAID          one against one, and anybody may assist either side or
	                  arrive as a third party - a SKIRMISH
	    WAR           a raid with capture points and an admin's approval,
	                  declared by command rather than by a button - see
	                  `sh_war.lua`

	THE SIDES ARE THREE, NOT TWO. `attackers`, `defenders` and `skirmishers`,
	and a skirmisher is at war with both. Phoenix leave skirmishers off the
	result bar; this schema puts them on it, which is what the server owner
	asked for and is the honest answer to "who won".

	WHAT LIVES WHERE:

	    sh_raid.lua   this - the state, the rules, the configs
	    sv_raid.lua   starting, ending, the kills and the cooldowns
	    cl_raid.lua   the scoreboard buttons, the confirmations, the HUD
	    derma/cl_raidstats.lua   /raidstats

	COOLDOWNS ARE PER FACTION AND GLOBAL TO THE FACTION: being in a raid at all
	- as caller, target, assister or skirmisher - puts your faction on cooldown
	when it ends. A faction on cooldown cannot call one and cannot be called
	on, which is the rule that stops three factions taking turns on one victim.
]]

ix.raid = ix.raid or {}

--[[
	The conflict in progress, or nil.

	    {
	        type       "raid" / "hostilities" / "war"
	        attacker   faction index of the caller
	        defender   faction index of the target
	        attackers  [faction index] = true, assisting the attacker
	        defenders  [faction index] = true, assisting the defender
	        skirmishers[faction index] = true, fighting everybody
	        startTime, endTime
	        kills      [faction index] = {kills = n, deaths = n,
	                                      players = {[steamID] = {...}}}
	    }
]]
ix.raid.current = ix.raid.current or nil

--- `[faction index] = CurTime()` it becomes free again.
ix.raid.cooldowns = ix.raid.cooldowns or {}

--- `[faction index] = CurTime()` a raid shield runs out.
ix.raid.shields = ix.raid.shields or {}

--- `[faction index] = CurTime()` another shield may be raised.
ix.raid.shieldCooldowns = ix.raid.shieldCooldowns or {}

--- The last conflict's kills, for `/raidstats`.
ix.raid.lastStats = ix.raid.lastStats or nil

--- Whether raids are switched off entirely, for events.
ix.raid.disabled = ix.raid.disabled or false

--------------------------------------------------------------------------------
-- The types
--------------------------------------------------------------------------------

ix.raid.types = ix.raid.types or {}

--[[
	Register one. `id` is what the configs are named after, so it is also what
	an admin sees in the terminal.
]]
function ix.raid.AddType(id, data)
	data.id = id
	ix.raid.types[id] = data

	ix.config.Add(id .. "Time", data.time or 600,
		string.format("How long a %s lasts, in seconds.", data.name), nil, {
		data = {min = 30, max = 21600}, category = "Raids"})

	ix.config.Add(id .. "Cooldown", data.cooldown or 1800,
		string.format("Seconds before a faction may take part in another %s.",
			data.name), nil, {
		data = {min = 0, max = 86400}, category = "Raids"})

	ix.config.Add(id .. "MinPlayers", data.minPlayers or 3,
		string.format("Members the target must have online to be %s'd.",
			data.name), nil, {
		data = {min = 1, max = 64}, category = "Raids"})
end

ix.raid.AddType("hostilities", {
	name = "Hostilities",
	time = 600,
	cooldown = 1800,
	minPlayers = 2,

	--- ONE AGAINST ONE. That is the whole difference from a raid.
	canAssist = false,
	canSkirmish = false,

	--- Anybody who may call a raid may call these.
	minRank = 2
})

ix.raid.AddType("raid", {
	name = "Raid",
	time = 900,
	cooldown = 2700,
	minPlayers = 3,

	canAssist = true,
	canSkirmish = true,

	--- NCO and up, matching `sh_factionmgmt.lua`'s ladder.
	minRank = 2
})

ix.config.Add("raidShieldDuration", 3600,
	"How long a raid shield protects a faction, in seconds.", nil, {
	data = {min = 60, max = 604800}, category = "Raids"})

ix.config.Add("raidShieldCooldown", 7200,
	"Seconds before a faction may raise another raid shield.", nil, {
	data = {min = 0, max = 604800}, category = "Raids"})

ix.config.Add("raidShieldRank", 3,
	"Lowest class rank that may raise a raid shield. 3 is officer.", nil, {
	data = {min = 1, max = 4}, category = "Raids"})

--------------------------------------------------------------------------------
-- Reading the state
--------------------------------------------------------------------------------

function ix.raid.InProgress()
	return ix.raid.current ~= nil
end

--- The faction index of a player, or nil. Used by nearly everything below.
function ix.raid.FactionOf(client)
	local character = IsValid(client) and client:GetCharacter()

	return character and character:GetFaction() or nil
end

--[[
	Which side a faction is on: "attackers", "defenders", "skirmishers", or
	nil for everybody who is not in it.

	The two principals are checked before the assist lists because they are the
	conflict - an attacker who somehow also appears in `defenders` is an
	attacker.
]]
function ix.raid.Side(faction)
	local raid = ix.raid.current

	if (not raid or not faction) then return nil end

	if (raid.attacker == faction) then return "attackers" end
	if (raid.defender == faction) then return "defenders" end

	for _, side in ipairs({"attackers", "defenders", "skirmishers"}) do
		if (raid[side][faction]) then return side end
	end

	return nil
end

--- Everybody in a faction who is online, as a count.
function ix.raid.MembersOnline(faction)
	local total = 0

	for _, client in player.Iterator() do
		if (ix.raid.FactionOf(client) == faction) then total = total + 1 end
	end

	return total
end

function ix.raid.OnCooldown(faction)
	return (ix.raid.cooldowns[faction] or 0) > CurTime()
end

function ix.raid.Shielded(faction)
	return (ix.raid.shields[faction] or 0) > CurTime()
end

--- Seconds left on a cooldown or shield, for the buttons and the notices.
function ix.raid.TimeLeft(store, faction)
	return math.max((store[faction] or 0) - CurTime(), 0)
end

--------------------------------------------------------------------------------
-- The rules
--------------------------------------------------------------------------------

--[[
	Everything both sides of a call have in common. `true`, or `false, reason`.

	Written once and asked twice - the client greys the button out with it and
	the server refuses with it - because a rule that exists in two places is a
	rule that will disagree with itself by the end of the month.
]]
function ix.raid.CanTakePart(client, faction)
	if (ix.raid.disabled) then
		return false, "Raids are switched off at the moment."
	end

	local mine = ix.raid.FactionOf(client)
	local data = mine and ix.faction.indices[mine]

	if (not data) then return false, "You are not in a faction." end
	if (data.isDefault) then
		return false, "Wastelanders are not a faction."
	end

	if (ix.faction.RaidImmune and ix.faction.RaidImmune(mine)) then
		return false, "Your faction takes no part in raids."
	end

	local rank = ix.factionmgmt and ix.factionmgmt.GetRank(client) or 0

	if (rank < 2) then
		return false, "You must be an NCO or above."
	end

	if (ix.raid.OnCooldown(mine)) then
		return false, string.format("Your faction is on cooldown for %d more "
			.. "seconds.", math.ceil(ix.raid.TimeLeft(ix.raid.cooldowns, mine)))
	end

	if (not faction) then return true end

	if (faction == mine) then
		return false, "You cannot fight your own faction."
	end

	local target = ix.faction.indices[faction]

	if (not target) then return false, "No such faction." end

	if (target.isDefault) then
		return false, "Wastelanders are not a faction."
	end

	if (ix.faction.RaidImmune and ix.faction.RaidImmune(faction)) then
		return false, string.format("%s takes no part in raids.", target.name)
	end

	if (ix.raid.Shielded(faction)) then
		return false, string.format("%s is under a raid shield for %d more "
			.. "seconds.", target.name,
			math.ceil(ix.raid.TimeLeft(ix.raid.shields, faction)))
	end

	if (ix.raid.OnCooldown(faction)) then
		return false, string.format("%s is on cooldown for %d more seconds.",
			target.name,
			math.ceil(ix.raid.TimeLeft(ix.raid.cooldowns, faction)))
	end

	return true
end

--- Whether this player may CALL `typeID` on `faction`.
function ix.raid.CanCall(client, typeID, faction)
	local info = ix.raid.types[typeID]

	if (not info) then return false, "No such kind of conflict." end

	if (ix.raid.InProgress()) then
		return false, "A conflict is already in progress."
	end

	--[[
		SOME KINDS ARE NOT CALLED, THEY ARE ARRANGED. A war goes through
		`/war`, an approval and `/startwar` - see `sh_war.lua` - so the answer
		here is no however senior the caller is.
	]]
	if (info.noButton) then
		return false, string.format("%s cannot be called from here.", info.name)
	end

	local can, reason = ix.raid.CanTakePart(client, faction)

	if (not can) then return false, reason end

	local rank = ix.factionmgmt and ix.factionmgmt.GetRank(client) or 0

	if (rank < (info.minRank or 2)) then
		return false, string.format("You must be %s or above to call %s.",
			ix.class.GetRankName(ix.raid.FactionOf(client), info.minRank or 2),
			info.name)
	end

	local minimum = ix.config.Get(typeID .. "MinPlayers", 3)
	local online = ix.raid.MembersOnline(faction)

	if (online < minimum) then
		return false, string.format("%s needs %d members online and has %d.",
			ix.faction.indices[faction].name, minimum, online)
	end

	return true
end

--[[
	Whether this player may join a conflict already running.

	`side` is "attackers", "defenders" or "skirmishers". Assisting and
	skirmishing are the same question with a different answer to "which side",
	which is why they are one function - the difference between them is what
	the type allows, not what the player is.
]]
function ix.raid.CanJoin(client, side)
	local raid = ix.raid.current

	if (not raid) then return false, "There is no conflict to join." end

	local info = ix.raid.types[raid.type]

	if (not info) then return false, "No such kind of conflict." end

	if (side == "skirmishers" and not info.canSkirmish) then
		return false, string.format("%s cannot be skirmished.", info.name)
	end

	if (side ~= "skirmishers" and not info.canAssist) then
		return false, string.format("%s cannot be assisted.", info.name)
	end

	local mine = ix.raid.FactionOf(client)

	if (ix.raid.Side(mine)) then
		return false, "Your faction is already in this conflict."
	end

	local can, reason = ix.raid.CanTakePart(client, nil)

	if (not can) then return false, reason end

	--[[
		THE CLOCK MATTERS. Joining a conflict with twenty seconds left is not
		joining it - it is arriving for the cooldown, which is a way of putting
		a faction on cooldown against its will.
	]]
	if (raid.endTime - CurTime() < 60) then
		return false, "There is not enough time left to join."
	end

	return true
end

--- Whether this player may raise a shield for their faction.
function ix.raid.CanShield(client)
	local mine = ix.raid.FactionOf(client)
	local data = mine and ix.faction.indices[mine]

	if (not data or data.isDefault) then
		return false, "You are not in a faction."
	end

	local rank = ix.factionmgmt and ix.factionmgmt.GetRank(client) or 0

	if (rank < ix.config.Get("raidShieldRank", 3)) then
		return false, string.format("You must be %s or above.",
			ix.class.GetRankName(mine, ix.config.Get("raidShieldRank", 3)))
	end

	if (ix.raid.Shielded(mine)) then
		return false, "Your faction already has a shield up."
	end

	local left = ix.raid.TimeLeft(ix.raid.shieldCooldowns, mine)

	if (left > 0) then
		return false, string.format("Another shield may be raised in %d "
			.. "seconds.", math.ceil(left))
	end

	if (ix.raid.Side(mine)) then
		return false, "You cannot raise a shield during a conflict."
	end

	return true
end

--------------------------------------------------------------------------------
-- Faction flags
--------------------------------------------------------------------------------

--[[
	`raidImmune` and `hidden`, both edited in `/liveedit` under FACTIONS.

	They are read through functions rather than off the table because a faction
	that has never been touched has neither field, and `nil` means "no" for
	both - which is the answer a schema full of ordinary factions wants.
]]
function ix.faction.RaidImmune(index)
	local data = ix.faction.indices[index]

	return data ~= nil and data.raidImmune == true
end

function ix.faction.Hidden(index)
	local data = ix.faction.indices[index]

	return data ~= nil and data.hiddenFromTab == true
end
