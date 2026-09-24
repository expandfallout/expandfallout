--[[
	Zones - the half that acts on them.

	See `sh_zones.lua` for what a zone is and why it is one of Helix's areas.

	THE TICK WALKS THE ZONES, NOT THE PLAYER'S CURRENT AREA.

	Helix's own `AreaThink` remembers one area per player, chosen arbitrarily
	from however the hash table iterated - so a radiation cloud drawn over a
	town would be the player's "area" some of the time and the town the rest.
	Every zone that acts on somebody is checked here on its own, so overlapping
	works the way it looks like it should: stand in a rad zone inside an
	out-of-bounds box and both of them happen to you.

	ONE SECOND, MATCHING `areaTickTime`. Radiation is per second by design -
	the numbers in `sh_radiation.lua` are Phoenix's per-second numbers - and a
	kill timer measured in whole seconds does not need finer.
]]

if (not SERVER) then return end

--- `sv_` sorts after `sh_`, so this is already there - but see `cl_zones.lua`.
ix.zones = ix.zones or {}

util.AddNetworkString("ixZoneWarn")
util.AddNetworkString("ixZoneCapture")
util.AddNetworkString("ixZonePending")

--------------------------------------------------------------------------------
-- Storing
--------------------------------------------------------------------------------

--[[
	Write the area list to disk NOW.

	The area plugin saves on its `SaveData` hook, which is a shutdown and a
	scheduled save - fine for something edited once a month, and not fine for a
	tool somebody is using and then wants to test by restarting. Every edit
	here asks the plugin to write, using its own function so there is still one
	place that decides the format.
]]
function ix.zones.Save()
	local plugin = ix.plugin and ix.plugin.Get("area")

	if (plugin and plugin.SaveData) then plugin:SaveData() end
end

--[[
	Create or replace a zone.

	`ix.area.Create` broadcasts the whole record, so replacing is how an edit is
	networked as well - there is no "change one property" message in the area
	plugin, and adding one would be a second path for the client's copy to
	drift from the server's.
]]
function ix.zones.Create(id, typeID, startPosition, endPosition, properties)
	properties = properties or {}

	properties.color = properties.color or
		(ix.zones.byID[typeID] and ix.zones.byID[typeID].color)
		or ix.config.Get("color")

	if (properties.display == nil) then properties.display = true end

	ix.area.Create(id, typeID, startPosition, endPosition, nil, properties)
	ix.zones.Save()

	return ix.area.stored[id]
end

function ix.zones.Remove(id)
	if (not ix.area.stored[id]) then return false end

	ix.area.Remove(id)
	ix.zones.Save()

	return true
end

--[[
	Change one property and tell everybody.

	Rebuilt through `Create` rather than poked in place, because the client's
	copy only ever changes through `ixAreaAdd` - writing the table here and
	forgetting the broadcast would leave a claim that only the server knew
	about, which is the kind of fault that shows up a week later.
]]
function ix.zones.SetProperty(id, key, value)
	local area = ix.area.stored[id]

	if (not area) then return false end

	local properties = table.Copy(area.properties or {})

	properties[key] = value

	ix.zones.Create(id, area.type, area.startPosition, area.endPosition,
		properties)

	return true
end

--------------------------------------------------------------------------------
-- Claiming
--------------------------------------------------------------------------------

function ix.zones.Release(client, id)
	local area = ix.zones.Get(id)

	if (not area) then return false, "There is no zone by that name." end

	local owner = ix.zones.Owner(area)

	if (not owner) then return false, "Nobody holds it." end

	if (not ix.zones.Holds(client, area)
	and not ix.admin.Can(client, "zone.claim.force")) then
		return false, "You do not hold it."
	end

	local ok, why = ix.zones.CanClaim(client)

	if (not ok) then return false, why end

	ix.zones.SetProperty(id, "owner", "")

	ix.log.Add(client, "zoneRelease", id, owner.name)

	for _, other in ipairs(player.GetAll()) do
		other:ChatPrint(string.format("[Area] %s is no longer held by %s.", id,
			owner.name))
	end

	return true, owner.name
end

--------------------------------------------------------------------------------
-- Taking one
--------------------------------------------------------------------------------

--- `[player] = {id = , progress = 0..1}`.
ix.zones.capturing = ix.zones.capturing or {}

--[[
	Tell one player how their capture is going.

	Sent every tick rather than only on change, because the bar interpolates
	between messages and a dropped one would leave it stuck. It is one float
	and a string to one player four times a second.
]]
local function SendCapture(client, record)
	net.Start("ixZoneCapture")
		net.WriteBool(record ~= nil)

		if (record) then
			net.WriteString(record.id)
			net.WriteFloat(record.progress)
		end
	net.Send(client)
end

function ix.zones.StopCapture(client, why)
	if (not ix.zones.capturing[client]) then return end

	ix.zones.capturing[client] = nil

	SendCapture(client, nil)

	if (why and IsValid(client)) then client:Notify(why) end
end

--[[
	Start taking an area. Returns `true`, or `false, reason`.

	IT IS A CAPTURE, NOT A COMMAND THAT SUCCEEDS. `/claimarea` used to write
	the owner and finish, which made holding ground a matter of typing first.
	Now the command starts a clock and you have to still be standing there when
	it runs out - which is something the other side can see happening and do
	something about.
]]
function ix.zones.BeginCapture(client, id)
	local area = ix.zones.Get(id)

	if (not area) then return false, "There is no zone by that name." end

	local zoneType = ix.zones.TypeOf(area)

	if (not zoneType or not zoneType.claimable) then
		return false, "That place cannot be claimed."
	end

	local ok, why = ix.zones.CanClaim(client)

	if (not ok) then return false, why end

	if (not ix.zones.Contains(area, client:GetPos() + client:OBBCenter())) then
		return false, "You are not standing in it."
	end

	if (ix.zones.Holds(client, area)) then return false, "You already hold it." end

	local owner = ix.zones.Owner(area)

	if (owner and not ix.admin.Can(client, "zone.claim.force")) then
		return false, string.format("%s holds it. They have to release it.",
			owner.name)
	end

	ix.zones.capturing[client] = {id = id, progress = 0}

	client:EmitSound("phoenix/ui/nv/menu_beep.mp3", 55)

	return true, ix.zones.CaptureTime(area)
end

--[[
	Finish one.

	Kept separate from the tick so the completion path is one place - it is the
	only thing here that writes an owner, and an owner written from two places
	is an owner one of them forgets to announce.
]]
local function FinishCapture(client, id)
	local area = ix.zones.Get(id)

	if (not area) then return end

	local claim = ix.zones.ClaimFor(client:GetCharacter())

	if (not claim) then return end

	ix.zones.SetProperty(id, "owner", claim)

	local holder = ix.zones.Owner(ix.zones.Get(id))

	ix.log.Add(client, "zoneClaim", id, holder and holder.name or "?")

	for _, other in ipairs(player.GetAll()) do
		other:ChatPrint(string.format("[Area] %s is now held by %s.", id,
			holder and holder.name or "?"))

		other:EmitSound("phoenix/ui/76/ui_discover_location_01.mp3", 60)
	end
end

--[[
	Four times a second, because a progress bar that moves once a second reads
	as a broken progress bar.
]]
timer.Create("ixZoneCapture", 0.25, 0, function()
	for client, record in pairs(ix.zones.capturing) do
		if (not IsValid(client)) then
			ix.zones.capturing[client] = nil

			continue
		end

		local area = ix.zones.Get(record.id)

		if (not area or not client:Alive() or not client:GetCharacter()) then
			ix.zones.StopCapture(client, "The claim was interrupted.")

			continue
		end

		if (not ix.zones.Contains(area,
		client:GetPos() + client:OBBCenter())) then
			ix.zones.StopCapture(client, "You left - the claim is off.")

			continue
		end

		record.progress = record.progress
			+ 0.25 / ix.zones.CaptureTime(area)

		if (record.progress < 1) then
			SendCapture(client, record)

			continue
		end

		ix.zones.capturing[client] = nil

		SendCapture(client, nil)

		FinishCapture(client, record.id)
	end
end)

--------------------------------------------------------------------------------
-- The tick
--------------------------------------------------------------------------------

--- `[player] = the time they walked into an out-of-bounds box`.
local oobSince = {}

--- `[player] = {[zone id] = when the next dose lands}`.
local radNext = {}

--[[
	Stop drawing the out-of-bounds warning.

	Sent when somebody leaves the box AND when they stop being alive in it. The
	second was missing, which is why the countdown stayed on the screen after
	it had killed you: the tick skips dead players entirely, so it cleared its
	own bookkeeping and never told the client anything.
]]
local function ClearWarning(client)
	if (not oobSince[client]) then return end

	oobSince[client] = nil

	if (not IsValid(client)) then return end

	net.Start("ixZoneWarn")
		net.WriteFloat(-1)
		net.WriteFloat(0)
	net.Send(client)
end

--[[
	Radiation and out of bounds, once a second.

	NOT ONE ZONE PER PLAYER. The rads from two overlapping clouds add up,
	because two clouds is more radiation than one and the alternative - picking
	whichever the table yielded first - would make a carefully layered map
	behave at random.
]]
local function Tick()
	if (not ix.area or not ix.area.stored) then return end

	for _, client in ipairs(player.GetAll()) do
		local character = client:GetCharacter()

		if (not character or not client:Alive()) then
			ClearWarning(client)

			radNext[client] = nil

			continue
		end

		local position = client:GetPos() + client:OBBCenter()
		local rads = 0
		local worst
		local inside = {}

		for _, entry in ipairs(ix.zones.At(position)) do
			local properties = ix.zones.Properties(entry.area)

			if (entry.area.type == "radiation") then
				--[[
					A RATE AND AN INTERVAL, tracked per zone per player.

					Each cloud has its own clock, so a heavy one every second
					and a light one every thirty both do what they say while
					somebody stands in both. Resetting the clock on entry means
					walking in and out repeatedly does not farm doses.
				]]
				local amount = tonumber(properties.radiation) or 0
				local interval = math.max(
					tonumber(properties.radInterval) or 1, 1)

				if (amount > 0) then
					inside[entry.id] = true

					radNext[client] = radNext[client] or {}

					local due = radNext[client][entry.id]

					if (not due) then
						radNext[client][entry.id] = CurTime() + interval
					elseif (CurTime() >= due) then
						radNext[client][entry.id] = CurTime() + interval
						rads = rads + amount
					end
				end
			elseif (entry.area.type == "outofbounds") then
				--[[
					The SHORTEST timer wins where boxes overlap. A box that
					kills in three seconds inside one that kills in ten means
					three - the tighter rule is the one drawn last and the one
					somebody meant.
				]]
				local killTime = math.max(tonumber(properties.killTime) or 5, 1)

				if (not worst or killTime < worst) then worst = killTime end
			end
		end

		--- Clocks for clouds they have left, dropped.
		if (radNext[client]) then
			for id in pairs(radNext[client]) do
				if (not inside[id]) then radNext[client][id] = nil end
			end
		end

		if (rads > 0) then character:AddRadiation(rads) end

		if (worst) then
			local since = oobSince[client]

			if (not since) then
				oobSince[client] = CurTime()
				since = CurTime()

				ix.log.Add(client, "zoneOutOfBounds", "entered", worst)
			end

			local left = math.max(worst - (CurTime() - since), 0)

			net.Start("ixZoneWarn")
				net.WriteFloat(left)
				net.WriteFloat(worst)
			net.Send(client)

			if (left <= 0) then
				ClearWarning(client)

				client:Notify("You strayed too far.")
				client:Kill()

				ix.log.Add(client, "zoneOutOfBounds", "died", worst)
			end
		else
			ClearWarning(client)
		end
	end
end

timer.Create("ixZoneTick", 1, 0, Tick)

--[[
	Death and disconnection clear everything.

	`PlayerDeath` rather than waiting for the next tick, because the warning is
	on screen for that whole second otherwise - and a countdown still ticking
	over a death screen is the fault that was reported.
]]
hook.Add("PlayerDeath", "ixZones", function(client)
	ClearWarning(client)
	ix.zones.StopCapture(client)
end)

hook.Add("PlayerSpawn", "ixZones", function(client)
	ClearWarning(client)
	ix.zones.StopCapture(client)

	radNext[client] = nil
end)

hook.Add("PlayerDisconnected", "ixZones", function(client)
	oobSince[client] = nil
	radNext[client] = nil
	ix.zones.capturing[client] = nil
end)

--------------------------------------------------------------------------------
-- The corner the tool is holding
--------------------------------------------------------------------------------

--[[
	Tell one client where their pending corner is, so it can draw the box.

	THE TOOL DOES ITS WORK ON THE SERVER ONLY - `TOOL:LeftClick` returns
	`true` immediately on the client, which is the sandbox idiom, because the
	client runs a predicted click that can fire more than once for one press.
	So the client does not know where the first corner went, and one small
	message per click is the whole of the fix.

	A zero vector with `false` means "there is no pending corner", rather than
	a second message that could be the one that goes missing.
]]
function ix.zones.SendPending(client, position)
	net.Start("ixZonePending")
		net.WriteBool(position ~= nil)
		net.WriteVector(position or vector_origin)
	net.Send(client)
end

--------------------------------------------------------------------------------
-- Logs
--------------------------------------------------------------------------------

ix.log.AddType("zoneCreate", function(client, id, typeID)
	return string.format("%s made a %s zone '%s'.", client:Name(), typeID, id)
end, FLAG_WARNING)

ix.log.AddType("zoneRemove", function(client, id)
	return string.format("%s deleted the zone '%s'.", client:Name(), id)
end, FLAG_DANGER)

ix.log.AddType("zoneClaim", function(client, id, holder)
	return string.format("%s claimed '%s' for %s.", client:Name(), id, holder)
end, FLAG_WARNING)

ix.log.AddType("zoneRelease", function(client, id, holder)
	return string.format("%s released '%s', held by %s.", client:Name(), id,
		holder)
end, FLAG_WARNING)

ix.log.AddType("zoneMusic", function(client, id, what)
	return string.format("%s set the zone '%s' to play %s.", client:Name(),
		id, what)
end, FLAG_NORMAL)

ix.log.AddType("zoneOutOfBounds", function(client, what, killTime)
	return string.format("%s %s an out-of-bounds zone (%d second(s)).",
		client:Name(), what, killTime)
end)
