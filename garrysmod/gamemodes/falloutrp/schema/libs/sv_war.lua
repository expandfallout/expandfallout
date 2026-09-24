--[[
	Wars, server side: declaring, approving, starting, and the ground itself.

	See `sh_war.lua` for what a war is and `sv_raid.lua` for everything a war
	shares with a raid - which is most of it.

	THE CAPTURE POINTS ARE BORROWED, NOT REBUILT. `ix_captureflag` already
	answers "who is standing here and for how long", draws its own outline and
	networks its holder; a war spawns two of them, reads them at the end and
	removes them. Writing a second capture system for the same question would
	be two answers to "who holds this ground".
]]

if (not SERVER) then return end

util.AddNetworkString("ixWarDeclared")
util.AddNetworkString("ixWarPoints")
util.AddNetworkString("ixWarQueue")

local KEY = "warpoints"

function ix.war.Save()
	ix.data.Set(KEY, ix.war.points, false, true)
end

function ix.war.Load()
	ix.war.points = ix.data.Get(KEY, {}, false, true) or {}
end

hook.Add("LoadData", "ixWar", ix.war.Load)
hook.Add("PostLoadData", "ixWar", ix.war.Load)

hook.Add("SaveData", "ixWar", function()
	ix.war.Save()
end)

--------------------------------------------------------------------------------
-- The ground
--------------------------------------------------------------------------------

--[[
	Show every war point for a few seconds, to one person.

	A war point is INVISIBLE between wars - deliberately, since a capture flag
	standing on a faction's doorstep is ground somebody will try to take on a
	Tuesday afternoon. That makes placing them a job done blind, so the tool
	asks for this after every action and the client draws a marker where each
	one is.

	Sent as a list of positions and names rather than as entities, because
	there is nothing there to be an entity.
]]
function ix.war.ShowPoints(client)
	local names, positions = {}, {}

	for uniqueID, record in pairs(ix.war.points) do
		local faction = ix.faction.teams[uniqueID]

		names[#names + 1] = faction and faction.name or uniqueID
		positions[#positions + 1] = record.position
	end

	net.Start("ixWarPoints")
		net.WriteUInt(#names, 8)

		for index = 1, #names do
			net.WriteString(names[index])
			net.WriteVector(positions[index])
		end
	net.Send(client)
end

concommand.Add("warpoint_show", function(client)
	if (not IsValid(client) or not client:IsSuperAdmin()) then return end

	ix.war.ShowPoints(client)
end)

--[[
	Put the points down for a war, and take them away afterwards.

	ONE PER SIDE. Each faction's own point is the ground the OTHER side has to
	come and take, which is what makes a war a war rather than a meeting in a
	field: both sides have something to lose and somewhere to defend.

	Spawned directly rather than through `ix.points.Add`, because these are not
	map furniture - they exist for half an hour and must not end up in the
	saved point list, where the next restart would bring them back with no war
	to explain them.
]]
function ix.war.PlacePoints(attacker, defender)
	ix.war.ClearPoints()

	for _, index in ipairs({attacker, defender}) do
		local data = ix.faction.indices[index]
		local record = data and ix.war.points[data.uniqueID]

		if (not record) then continue end

		local entity = ents.Create("ix_captureflag")

		if (not IsValid(entity)) then continue end

		entity:SetPos(record.position)
		entity:SetAngles(record.angles or angle_zero)
		entity:SetModel("models/mosi/fnv/props/factions/flagpole_small.mdl")
		entity:Spawn()

		--[[
			AFTER `Spawn`, for the reason `sv_points.lua` records: a network
			variable set before it has nowhere to go and is silently lost.
		]]
		entity:SetPointName(string.format("%s - War", data.name))
		entity.ixWarFaction = index

		--[[
			THE FLAG THAT MAKES ASSISTS COUNT. `ix_captureflag` groups the
			people standing on it by their FACTION unless this is set, in which
			case it groups them by their SIDE - so a faction that came to help
			attack can take the defender's ground, and cannot contest ground
			its own side is taking. See `ENT:ClaimOf`.
		]]
		entity.ixWarPoint = true

		--[[
			CONFIGURED THE WAY A PLACED POINT IS.

			`ix_captureflag` reads its capture time, radius and payout from
			`self.ixRecord.data` - the record a map-placed point carries. A war
			point has no record, so it is given one: the same shape, made here,
			with no `id` so nothing tries to save it.

			`payout` is deliberately absent. A war point pays in ground, not in
			caps, and paying a faction for holding one would make standing in a
			square more profitable than fighting over it.
		]]
		--[[
			ALREADY THEIRS, which is what makes it ground worth defending.

			The owner is the SIDE - `side:attackers` or `side:defenders`, the
			same claim `ENT:ClaimOf` builds for a war point - so the faction
			whose point it is cannot capture its own (the flag returns early
			when the claim matches the owner) and the other side has something
			to take rather than an empty square to stand in first.
		]]
		local side = (index == attacker) and "side:attackers"
			or "side:defenders"

		entity.ixRecord = {
			data = {
				name = entity:GetPointName(),
				captureTime = ix.config.Get("warPointCapture", 120),
				radius = 200,
				owner = side
			}
		}

		entity:SetRadius(200)
		entity:Announce()

		ix.war.placed[#ix.war.placed + 1] = entity
	end
end

--[[
	Take the flags away.

	THE LIST AND THEN THE MAP, because the list can be lost: a Lua refresh
	rebuilds `ix.war.placed` as an empty table while the entities it named are
	still standing in the world, and a war point left behind after the war is
	ground people will keep fighting over for no reason.

	The sweep is cheap - `ixWarPoint` is set on exactly these - and it is the
	half that cannot go stale.
]]
function ix.war.ClearPoints()
	for _, entity in ipairs(ix.war.placed) do
		if (IsValid(entity)) then entity:Remove() end
	end

	ix.war.placed = {}

	for _, entity in ipairs(ents.FindByClass("ix_captureflag")) do
		if (IsValid(entity) and entity.ixWarPoint) then
			entity:Remove()
		end
	end
end

--[[
	WHO WON, in one sentence.

	A war is decided by ground: whoever holds points they did not start with
	has taken something, and the side that holds BOTH has won outright. Read
	off the entities rather than remembered as they change - the state at the
	final whistle is the one that matters.

	Returns the faction index of the winner, or nil for a draw.
]]
function ix.war.Winner()
	local raid = ix.raid.current

	if (not raid) then return nil end

	local held = {attackers = 0, defenders = 0}

	for _, entity in ipairs(ix.war.placed) do
		if (not IsValid(entity)) then continue end

		local owner = entity:Data().owner

		if (owner == "side:attackers") then
			held.attackers = held.attackers + 1
		elseif (owner == "side:defenders") then
			held.defenders = held.defenders + 1
		end
	end

	--[[
		THE DEFENDER STARTS AHEAD, which is what defending is: holding what you
		already have is a win, and a war that ran out of time with nothing
		taken goes to the people who were there first. So this compares against
		what each side STARTED with rather than counting flags - one each.
	]]
	if (held.attackers > held.defenders) then return raid.attacker end
	if (held.defenders > held.attackers) then return raid.defender end

	return nil
end

--[[
	A war point has changed hands. `claim` is the side that took it.

	THIS IS HOW A WAR ENDS. Not the clock - taking the enemy's ground is the
	win condition, and a war that carried on afterwards would be a war whose
	objective did not matter.

	One frame later, so the capture's own announcement and sound land before
	the war's ending does.
]]
function ix.war.PointTaken(entity, claim)
	if (not ix.raid.current or ix.raid.current.type ~= "war") then return end

	timer.Simple(0, function()
		if (not ix.raid.current or ix.raid.current.type ~= "war") then return end

		ix.raid.Stop(false)
	end)
end

--[[
	A war ending is a raid ending plus the ground. Wrapped rather than hooked,
	because the points have to come down whichever way it ended - the clock,
	an admin, or the last person leaving.
]]
local RaidStop = ix.raid.Stop

function ix.raid.Stop(bForced)
	local raid = ix.raid.current
	local bWar = raid and raid.type == "war"

	--- Read BEFORE the points come down, or there is nothing to read.
	local winner = bWar and ix.war.Winner() or nil

	RaidStop(bForced)

	if (not bWar) then return end

	ix.war.ClearPoints()

	--[[
		A NAME, NOT A LEDGER. "The ground at the end: X - War: Attackers, Y -
		War: nobody" is the state of two entities; nobody asked what the flags
		said, they asked who won.
	]]
	if (winner) then
		local data = ix.faction.indices[winner]

		ix.raid.Announce(string.format("%s has won the war!",
			data and data.name or "Somebody"))
	else
		ix.raid.Announce("The war ended with neither side taking ground.")
	end
end

--[[
	THE QUEUE, sent to the people who can act on it.

	The placer tool needs it: "which two factions am I placing points for" is
	the question somebody has open the tool to answer, and a list of every
	faction on the server does not answer it.

	Sent to staff rather than broadcast, for the same reason a declaration is
	not announced - a war that has not been approved is not news yet.
]]
function ix.war.SyncQueue(client)
	local queue = {}

	for index, entry in pairs(ix.war.pending) do
		queue[#queue + 1] = {
			attacker = index,
			defender = entry.defender,
			approved = entry.approved == true,
			reason = entry.reason
		}
	end

	--[[
		WHICH FACTIONS HAVE GROUND, as a set of ids.

		The tool panel is CLIENT side and `ix.war.points` is not - it is
		positions on the server, and the client has no business knowing where
		they are until somebody asks to see them. All the panel needs is which
		ids have one, which is what this is.
	]]
	local placed = {}

	for uniqueID in pairs(ix.war.points) do
		placed[uniqueID] = true
	end

	net.Start("ixWarQueue")
		net.WriteTable(queue)
		net.WriteTable(placed)

	if (IsValid(client)) then
		net.Send(client)

		return
	end

	local staff = {}

	for _, listener in player.Iterator() do
		if (ix.admin.Can(listener, "war.approve") or listener:IsSuperAdmin()) then
			staff[#staff + 1] = listener
		end
	end

	if (#staff > 0) then net.Send(staff) end
end

hook.Add("PlayerLoadedCharacter", "ixWarQueue", function(client)
	timer.Simple(2, function()
		if (not IsValid(client)) then return end

		if (ix.admin.Can(client, "war.approve") or client:IsSuperAdmin()) then
			ix.war.SyncQueue(client)
		end
	end)
end)

--------------------------------------------------------------------------------
-- Declaring
--------------------------------------------------------------------------------

ix.command.Add("War", {
	description = "Declare war on a faction, with a reason. Faction leads.",
	arguments = {ix.type.string, ix.type.text},

	OnRun = function(self, client, name, reason)
		local target

		for _, data in ipairs(ix.faction.indices) do
			if (ix.util.StringMatches(data.name, name)
			or ix.util.StringMatches(data.uniqueID, name)) then
				target = data

				break
			end
		end

		if (not target) then return "No faction by that name." end

		local can, why = ix.war.CanDeclare(client, target.index)

		if (not can) then return why end

		reason = string.Trim(reason or "")

		if (#reason < 10) then
			return "Give a reason worth reading - at least ten characters."
		end

		local mine = ix.raid.FactionOf(client)

		ix.war.pending[mine] = {
			defender = target.index,
			reason = reason,
			declaredBy = client:SteamID(),
			declaredByName = client:Name(),
			declaredAt = os.time(),
			approved = false
		}

		--[[
			STAFF ARE TOLD, EVERYBODY ELSE IS NOT.

			A declaration is not the war and announcing it to the server would
			start the fighting before anybody had approved anything. The people
			who can approve it are the people who hear about it.
		]]
		local attackerData = ix.faction.indices[mine]

		ix.war.TellStaff(mine, target.index, reason, client:Name(), false)
		ix.war.SyncQueue()

		ix.log.Add(client, "warDeclare", attackerData.name, target.name, reason)

		return string.format("War declared on %s. Staff have been told; it "
			.. "starts when they approve it.", target.name)
	end
})

--[[
	`/warreason <faction> approve|deny` - the whole of the staff decision.

	A COMMAND RATHER THAN A WINDOW. A box that appears over whatever staff are
	doing is a box that gets dismissed by whoever happened to be moving their
	mouse, and a war can wait: the declaration goes into the queue, staff are
	told in chat, and they answer when they are ready. `/warlist` is the queue.

	`/acceptwarreason` is still here as the long way round, because it is what
	the first version of this called it and somebody has it in their notes.
]]
ix.command.Add("WarReason", {
	description = "Approve or deny a declared war: /warreason <faction> "
		.. "approve|deny.",
	arguments = {ix.type.string, ix.type.string},
	alias = {"AcceptWarReason"},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "war.approve")
	end,

	OnRun = function(self, client, name, answer)
		answer = string.lower(answer or "")

		if (answer ~= "approve" and answer ~= "deny") then
			return "Say approve or deny."
		end

		for index, entry in pairs(ix.war.pending) do
			local data = ix.faction.indices[index]

			if (not data) then continue end

			if (not ix.util.StringMatches(data.name, name)
			and not ix.util.StringMatches(data.uniqueID, name)) then
				continue
			end

			local defender = ix.faction.indices[entry.defender]

			if (answer == "deny") then
				ix.war.pending[index] = nil

				ix.war.SyncQueue()
				ix.log.Add(client, "warCancel", data.name)

				return string.format("Denied: %s vs %s.", data.name,
					defender and defender.name or "?")
			end

			entry.approved = true

			ix.war.SyncQueue()
			ix.log.Add(client, "warApprove", data.name,
				defender and defender.name or "?")

			return string.format("Approved: %s vs %s. Place their war points, "
				.. "then /startwar %s.", data.name,
				defender and defender.name or "?", data.uniqueID)
		end

		return "No declared war from that faction."
	end
})

--[[
	Tell staff what has been declared or started, in chat.

	One function, because the two moments want the same three lines and the
	second one is the reason this exists: staff approve a war, place points,
	and by the time somebody runs `/startwar` the declaration has scrolled off.
]]
function ix.war.TellStaff(attacker, defender, reason, who, bStarted)
	for _, staff in player.Iterator() do
		if (not ix.admin.Can(staff, "war.approve")) then continue end

		net.Start("ixWarDeclared")
			net.WriteUInt(attacker, 8)
			net.WriteUInt(defender, 8)
			net.WriteString(reason or "")
			net.WriteString(who or "")
			net.WriteBool(bStarted == true)
		net.Send(staff)
	end
end

--[[
	`/startwar` - with no argument when there is only one to start.

	ONE CONFLICT AT A TIME is the rule the whole system is built on, so naming
	the faction is usually typing out something the server already knows. It is
	still accepted, for the case that makes it necessary: two factions have
	both declared and both been approved, and somebody has to say which.
]]
ix.command.Add("StartWar", {
	description = "Start an approved war. The faction is only needed when "
		.. "more than one is approved.",
	arguments = {bit.bor(ix.type.string, ix.type.optional)},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "war.approve")
	end,

	OnRun = function(self, client, name)
		if (ix.raid.InProgress()) then
			return "A conflict is already in progress."
		end

		--- Everything approved, and the one that was asked for if any.
		local approved = {}

		for index, entry in pairs(ix.war.pending) do
			if (not entry.approved) then continue end

			local data = ix.faction.indices[index]

			if (not data) then continue end

			if (name and name ~= "" and not ix.util.StringMatches(data.name, name)
			and not ix.util.StringMatches(data.uniqueID, name)) then
				continue
			end

			approved[#approved + 1] = {index = index, entry = entry, data = data}
		end

		if (#approved == 0) then
			return name and name ~= ""
				and "That faction has no approved war."
				or "No war has been approved. /warlist shows the queue."
		end

		if (#approved > 1) then
			local names = {}

			for _, ready in ipairs(approved) do
				names[#names + 1] = ready.data.uniqueID
			end

			return "More than one war is approved - say which: "
				.. table.concat(names, ", ")
		end

		local index = approved[1].index
		local entry = approved[1].entry
		local data = approved[1].data
		local defender = ix.faction.indices[entry.defender]

		--[[
			CHECKED AGAIN AT THE MOMENT IT STARTS, and for BOTH factions.

			A war approved an hour ago is a war whose sides may since have been
			raided, shielded or emptied - and the attacker's own cooldown is as
			binding as the defender's. Checking only the defender was how a
			faction that had just fought a war could be walked straight into
			another one.
		]]
		for _, side in ipairs({{index, data}, {entry.defender, defender}}) do
			if (ix.raid.OnCooldown(side[1])) then
				return string.format("%s is on cooldown for %d more seconds.",
					side[2].name,
					math.ceil(ix.raid.TimeLeft(ix.raid.cooldowns, side[1])))
			end
		end

		if (ix.raid.Shielded(entry.defender)) then
			return string.format("%s is shielded.", defender.name)
		end

		local minimum = ix.config.Get("warMinPlayers", 4)

		if (ix.raid.MembersOnline(entry.defender) < minimum) then
			return string.format("%s needs %d members online.",
				defender.name, minimum)
		end

		local ready, missing = ix.war.CanStart(index, entry.defender)

		if (not ready) then return missing end

		--[[
			THE CONFLICT FIRST, THEN THE GROUND.

			A war point reads `ix.raid.current` when it announces who holds it -
			the side name and the principal faction's colour both come from
			there - so placing the flags before the war exists gave two grey
			ones labelled from nothing.
		]]
		ix.raid.Start("war", index, entry.defender, client)
		ix.war.PlacePoints(index, entry.defender)

		ix.raid.Announce(string.format("The reason given: %s", entry.reason))

		--- Staff get the declaration again, now that it is actually happening.
		ix.war.TellStaff(index, entry.defender, entry.reason,
			entry.declaredByName or "?", true)

		ix.war.pending[index] = nil

		ix.war.SyncQueue()
		ix.log.Add(client, "warStart", data.name, defender.name)
	end
})

ix.command.Add("WarList", {
	description = "List declared wars and whether they are approved.",

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "war.approve")
	end,

	OnRun = function(self, client)
		local lines = {}

		for index, entry in pairs(ix.war.pending) do
			local attacker = ix.faction.indices[index]
			local defender = ix.faction.indices[entry.defender]

			if (not attacker or not defender) then continue end

			lines[#lines + 1] = string.format("%s vs %s [%s] - %s",
				attacker.name, defender.name,
				entry.approved and "approved" or "waiting", entry.reason)
		end

		if (#lines == 0) then return "No wars have been declared." end

		for _, line in ipairs(lines) do
			client:ChatPrint(line)
		end
	end
})

ix.command.Add("WarCancel", {
	description = "Throw out a declared war.",
	arguments = {ix.type.string},

	OnCheckAccess = function(self, client)
		return ix.admin.Can(client, "war.approve")
	end,

	OnRun = function(self, client, name)
		for index in pairs(ix.war.pending) do
			local data = ix.faction.indices[index]

			if (data and (ix.util.StringMatches(data.name, name)
			or ix.util.StringMatches(data.uniqueID, name))) then
				ix.war.pending[index] = nil

				ix.war.SyncQueue()
				ix.log.Add(client, "warCancel", data.name)

				return string.format("%s's war declaration is gone.",
					data.name)
			end
		end

		return "No declared war from that faction."
	end
})

--------------------------------------------------------------------------------
-- The ground, placed by an admin
--------------------------------------------------------------------------------

ix.command.Add("WarPointSet", {
	description = "Record where you are standing as a faction's war point.",
	adminOnly = true,
	arguments = {ix.type.string},

	OnRun = function(self, client, name)
		for _, data in ipairs(ix.faction.indices) do
			if (ix.util.StringMatches(data.name, name)
			or ix.util.StringMatches(data.uniqueID, name)) then
				local trace = client:GetEyeTrace()

				ix.war.points[data.uniqueID] = {
					position = trace.HitPos + trace.HitNormal * 4,
					angles = Angle(0, client:EyeAngles().y, 0)
				}

				ix.war.Save()
				ix.log.Add(client, "warPoint", data.name)

				return string.format("%s's war point is where you are "
					.. "looking.", data.name)
			end
		end

		return "No faction by that name."
	end
})

ix.command.Add("WarPointClear", {
	description = "Forget a faction's war point.",
	adminOnly = true,
	arguments = {ix.type.string},

	OnRun = function(self, client, name)
		for _, data in ipairs(ix.faction.indices) do
			if (ix.util.StringMatches(data.name, name)
			or ix.util.StringMatches(data.uniqueID, name)) then
				ix.war.points[data.uniqueID] = nil

				ix.war.Save()

				return string.format("%s has no war point now.", data.name)
			end
		end

		return "No faction by that name."
	end
})

ix.command.Add("WarPoints", {
	description = "List which factions have war points.",
	adminOnly = true,

	OnRun = function(self, client)
		local lines = {}

		for _, data in ipairs(ix.faction.indices) do
			if (ix.war.points[data.uniqueID]) then
				lines[#lines + 1] = data.name
			end
		end

		return #lines > 0 and ("War points: " .. table.concat(lines, ", "))
			or "No faction has a war point."
	end
})

ix.log.AddType("warDeclare", function(client, attacker, defender, reason)
	return string.format("%s declared war for %s on %s: %s", client:Name(),
		attacker, defender, reason)
end, FLAG_WARNING)

ix.log.AddType("warApprove", function(client, attacker, defender)
	return string.format("%s approved %s's war on %s.", client:Name(),
		attacker, defender)
end, FLAG_WARNING)

ix.log.AddType("warStart", function(client, attacker, defender)
	return string.format("%s started the war: %s vs %s.", client:Name(),
		attacker, defender)
end, FLAG_DANGER)

ix.log.AddType("warCancel", function(client, attacker)
	return string.format("%s threw out %s's war declaration.", client:Name(),
		attacker)
end)

ix.log.AddType("warPoint", function(client, faction)
	return string.format("%s set %s's war point.", client:Name(), faction)
end)
