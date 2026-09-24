--[[
	Wars: a raid with ground to take and somebody's permission to start.

	A war is the same conflict as a raid - `sh_raid.lua` owns the sides, the
	clock, the cooldowns and the scoreline - with three differences, and they
	are the reasons it exists as its own thing:

	    IT IS DECLARED WITH A REASON. `/war <faction> <reason>` does not start
	    anything. It writes down what the faction says the war is about.

	    STAFF APPROVE IT. `/acceptwarreason <faction>` accepts the reason and
	    puts the war in the queue; `/startwar` is what actually begins it, when
	    everybody is ready and the points are placed.

	    THERE IS GROUND. One capture point per side, or one in the middle, and
	    whoever holds them at the end is part of the answer to who won.

	WHY THE THREE STEPS: a war is an event, and events are arranged. Phoenix
	require an admin's approval for exactly this reason - their raid type
	carries `adminApproval = true` and its `canCallFunction` returns false, so
	the button can never start one.

	WAR POINTS ARE PLACED ONCE AND KEPT. `/warpointset` records where a
	faction's point is; the entity itself only exists while a war is running,
	because a capture point sitting on a faction's doorstep between wars is
	ground somebody will try to take on a Tuesday afternoon.
]]

ix.war = ix.war or {}

--- `[faction uniqueID] = {position, angles}` - where each side's ground is.
ix.war.points = ix.war.points or {}

--[[
	Declared wars waiting to be dealt with.

	    [attacker faction index] = {
	        defender, reason, declaredBy, declaredAt, approved
	    }

	One per attacking faction: declaring a second war replaces the first, which
	is what a faction that changed its mind means by it.
]]
ix.war.pending = ix.war.pending or {}

--- The entities placed for the war in progress, so they can be cleared.
ix.war.placed = ix.war.placed or {}

--[[
	WHO MAY APPROVE A WAR, as its own permission rather than as "admin".

	The rank that arranges events is not always the rank that bans people, and
	this schema's admin ranks are built out of permissions for exactly that
	reason - see `sh_adminbase.lua`. A server can hand war approval to its
	event team without handing them anything else.
]]
if (ix.admin and ix.admin.RegisterPermission) then
	ix.admin.RegisterPermission("war.approve",
		"Approve, start and cancel declared wars", "World")
end

ix.config.Add("warPointCapture", 120,
	"Seconds of standing on a war point to take it.", nil, {
	data = {min = 10, max = 3600}, category = "Raids"})

--[[
	MULTICAP: how many of them it takes.

	Off, a war point falls to whoever walks onto it, which on a big map is a
	war decided by the one person who left the fight. On, it takes a group -
	and the number is the whole setting: two is "bring a friend", six is "bring
	the platoon and hold the ground while you do it".
]]
ix.config.Add("warMultiCap", false,
	"Whether a war point needs several people on it to be taken.", nil, {
	category = "Raids"})

ix.config.Add("warCapPlayers", 2,
	"How many people it takes to capture a war point, when multicap is on.",
	nil, {data = {min = 1, max = 32}, category = "Raids"})

--[[
	The war type, registered with the raid library so every scoreboard button,
	assist rule and statistic works on it without knowing what a war is.

	`minRank = 4` is the faction LEAD and nobody else - and it is only the
	rank needed to DECLARE one, since the button that would call it is never
	shown: `ix.raid.CanCall` refuses a war outright below.
]]
ix.raid.AddType("war", {
	name = "War",
	time = 1800,
	cooldown = 7200,
	minPlayers = 4,

	canAssist = true,
	canSkirmish = true,

	minRank = 4,

	--[[
		THE BUTTON CANNOT START ONE. A war goes through the commands, and a
		scoreboard button that quietly did the same thing would be a way round
		the approval - which is the only part of a war that is not automatic.
	]]
	noButton = true
})

--- Whether a faction has somewhere to fight over. Takes a uniqueID.
function ix.war.HasPoint(uniqueID)
	return ix.war.points[uniqueID] ~= nil
end

--[[
	Whether this player may declare a war on `faction`. `true`, or a reason.

	The rank is the LEAD's, and the rest of the rules are the raid's - a
	faction on cooldown, shielded or immune is as unavailable for a war as it
	is for a raid, and a war that could be declared on a faction that cannot
	fight would sit in the queue for ever.
]]
function ix.war.CanDeclare(client, faction)
	local mine = ix.raid.FactionOf(client)
	local rank = ix.factionmgmt and ix.factionmgmt.GetRank(client) or 0

	if (rank < 4) then
		return false, "Only a faction lead may declare war."
	end

	local can, reason = ix.raid.CanTakePart(client, faction)

	if (not can) then return false, reason end

	--[[
		THE GROUND IS NOT CHECKED HERE, and that is the order of events.

		A war is declared first and arranged afterwards: staff read the reason,
		approve it, and THEN put the points down for the two factions that are
		in the queue - which is when they know which two those are. Refusing a
		declaration because nobody had placed a flag yet would mean placing
		flags for wars nobody has declared.

		`/startwar` is where the ground is required. See `sv_war.lua`.
	]]
	return true
end

--[[
	Whether a war between these two could actually START.

	At least ONE point, not both: a single point in the middle is a war over
	one piece of ground, which is a shape the server owner asked for, and two
	is one each. None at all is a fight with nothing to take.
]]
function ix.war.CanStart(attacker, defender)
	local attackerData = ix.faction.indices[attacker]
	local defenderData = ix.faction.indices[defender]

	if (not attackerData or not defenderData) then
		return false, "One of those factions is gone."
	end

	if (not ix.war.HasPoint(attackerData.uniqueID)
	and not ix.war.HasPoint(defenderData.uniqueID)) then
		return false, string.format("Neither %s nor %s has a war point. Place "
			.. "one with the War Point Placer.", attackerData.name,
			defenderData.name)
	end

	return true
end
