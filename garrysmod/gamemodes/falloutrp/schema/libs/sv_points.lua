--[[
	Points - storing them, spawning them, taking them away.

	See `sh_points.lua` for what a point is and why it is not a zone.

	LOADED FROM `LoadData`, NOT `InitPostEntity`.

	`hook.Add("InitPostEntity", ...)` in this schema's `libs/` registers fine
	and never runs - the schema is included during gamemode initialisation,
	after the event. It has cost this project loot tables, placed lootables,
	permaprops and the container sweep, and the failure is silent in the worst
	possible way: the load leaves an empty table and the next save writes that
	over the file.

	So: `LoadData` first, `PostLoadData` and a timer as belt and braces, and a
	SAVE GUARD that refuses to write anything until a load has happened. Losing
	a session's edits is recoverable. Overwriting the file is not.

	PER MAP. A position means nothing on another map, and restoring one map's
	cap stashes onto another drops them all through the floor.
]]

if (not SERVER) then return end

ix.points = ix.points or {}

--- `[id] = {type, position, angles, model, data}`.
ix.points.stored = ix.points.stored or {}
ix.points.nextID = ix.points.nextID or 1

--- Nothing is written until something has been read. See the header.
ix.points.loaded = false

local KEY = "points"

--------------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------------

function ix.points.Save()
	if (not ix.points.loaded) then return end

	local out = {}

	for id, record in pairs(ix.points.stored) do
		out[id] = {
			type = record.type,
			position = record.position,
			angles = record.angles,
			model = record.model,
			data = record.data
		}
	end

	ix.data.Set(KEY, out)
end

function ix.points.Load()
	if (ix.points.loaded) then return end

	ix.points.stored = ix.data.Get(KEY, {}) or {}
	ix.points.loaded = true

	local highest = 0
	local spawned = 0

	for id, record in pairs(ix.points.stored) do
		--[[
			THE KEY IS KEPT AS IT CAME BACK, not converted.

			`ix.data` goes through JSON, which has no integer keys - so a table
			saved with `[3]` comes back with `["3"]`. Converting here would give
			the record an id that no longer indexes the table it is in, and
			removing a point would answer "that is not a placed point" for
			every point that had survived a restart.

			`tonumber` is used only to find the highest, which is arithmetic
			and not a lookup.
		]]
		record.id = id

		--[[
			EVERY CAPTURE POINT STARTS THE SESSION UNHELD.

			A point is held by whoever is standing on it and willing to keep
			standing on it. Carrying yesterday's holder across a restart would
			mean a faction that logged off at three in the morning still owning
			the map at noon, and being paid for it - the whole thing is meant
			to be fought over daily, so it starts empty daily.

			Areas are the opposite and keep their owner: an area is a claim, a
			point is a fight.
		]]
		if (record.type == "captureflag" and record.data) then
			record.data.owner = nil
		end

		highest = math.max(highest, tonumber(id) or 0)

		--[[
			A stash looted shortly before the restart stays looted.
			`ix.points.Tick` puts it back when its wall clock says so - the
			same moment it would have come back had nothing restarted.
		]]
		if (not ix.points.ShouldExist(record)) then continue end

		if (ix.points.Spawn(record)) then spawned = spawned + 1 end
	end

	ix.points.nextID = highest + 1

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] %d point(s) restored\n", spawned))
end

hook.Add("LoadData", "ixPoints", ix.points.Load)
hook.Add("PostLoadData", "ixPoints", ix.points.Load)
timer.Simple(10, ix.points.Load)

--[[
	A map cleanup takes the entities and leaves the records, so they are put
	back. `PostCleanupMap` rather than `PostCleanupMap`'s partner because the
	entities are gone by then and re-spawning is all that is left to do.
]]
hook.Add("PostCleanupMap", "ixPoints", function()
	if (not ix.points.loaded) then return end

	for _, record in pairs(ix.points.stored) do
		record.entity = nil

		ix.points.Spawn(record)
	end
end)

--------------------------------------------------------------------------------
-- Waiting to come back
--------------------------------------------------------------------------------

--[[
	Should this record have an entity in the world right now?

	Only cap stashes ever answer no. A looted one is REMOVED rather than hidden
	- see the header of `ix_capstash.lua` for why the hiding was abandoned -
	so "empty and still on its timer" is a record with nothing standing on it.
]]
function ix.points.ShouldExist(record)
	if (record.type ~= "capstash") then return true end

	local data = record.data or {}

	if ((tonumber(data.remaining) or 0) > 0) then return true end

	--- Its time has come; the tick below will fill it and put it back.
	return (tonumber(data.refillAt) or 0) <= os.time()
end

--[[
	Put back anything whose timer has run out.

	ON THE RECORD, NOT ON THE ENTITY. A stash waiting to come back has no
	entity to run a `Think`, which is exactly why the first version could never
	have worked: it hid the entity so that its own `Think` could unhide it, and
	the moment the entity went the timer went with it.

	Once a second over a list of tens of records. `os.time` throughout, so the
	wait means the same thing across a restart.

	IT COUNTS ITSELF. "It does not grow back" has two completely different
	causes with no way to tell them apart from in game - either this tick is not
	running at all, or it is running and the plant is not answering it - and
	`fo_point_report` prints both numbers. They cost one addition a second.
]]
ix.points.ticks = ix.points.ticks or 0
ix.points.ripened = ix.points.ripened or 0

function ix.points.Tick()
	if (not ix.points.loaded) then return end

	ix.points.ticks = ix.points.ticks + 1

	local now = os.time()
	local changed = false

	for _, record in pairs(ix.points.stored) do
		--[[
			PLANTS RIPEN HERE, and they are the one kind that is checked while
			its entity is perfectly valid - so this is above the "missing" test
			rather than below it.

			It was an `ENT:Think` on the plant itself and the fruit never came
			back. The wait belongs here for the reason written at the top of
			this file: a timer over the records is the thing that is proven to
			run, and the entity's own think is one more moving part between a
			deadline and the moment it passes.
		]]
		if (record.type == "plant") then
			local entity = record.entity

			if (IsValid(entity) and entity.Ripen and entity:Ripen()) then
				ix.points.ripened = ix.points.ripened + 1
				changed = true
			end
		end

		if (IsValid(record.entity)) then continue end

		--[[
			ANYTHING BUT A STASH THAT IS MISSING IS SIMPLY PUT BACK.

			A cap stash is allowed to be absent - that is what being looted
			means, and the branch below decides when it returns. Every other
			kind is meant to be standing there, so a missing one is a map
			cleanup, a `lua_run ents.Remove`, or something else nobody asked
			for. The record is authoritative; the entity is a consequence of
			it. Without this a cleanup took every plant and flag on the map
			until the next restart.
		]]
		if (record.type ~= "capstash") then
			ix.points.Spawn(record)

			continue
		end

		local data = record.data or {}

		if ((tonumber(data.remaining) or 0) > 0) then
			--- Never looted, or refilled and not yet put back.
			ix.points.Spawn(record)

			continue
		end

		if ((tonumber(data.refillAt) or 0) > now) then continue end

		data.remaining = math.max(tonumber(data.caps) or 250, 0)
		data.refillAt = 0
		changed = true

		local entity = ix.points.Spawn(record)

		if (IsValid(entity)) then
			entity:EmitSound("phoenix/ui/nv/itm_bottle_up_02.mp3", 60, 100,
				0.4)
		end
	end

	if (changed) then ix.points.Save() end
end

timer.Create("ixPointsTick", 1, 0, ix.points.Tick)

--------------------------------------------------------------------------------
-- Making them exist
--------------------------------------------------------------------------------

--[[
	Turn one record into the thing standing in the world.

	The record is handed to the entity as `ixRecord`, so the entity can write
	its own state back - the caps left in a stash, who holds a flag - without
	the library having to know what each kind keeps.
]]
function ix.points.Spawn(record)
	if (IsValid(record.entity)) then return record.entity end

	local pointType = ix.points.byID[record.type]

	if (not pointType) then
		ErrorNoHalt(string.format(
			"[falloutrp] point type '%s' does not exist, skipping\n",
			tostring(record.type)))

		return
	end

	local entity = ents.Create(pointType.class)

	if (not IsValid(entity)) then return end

	entity:SetModel(record.model or pointType.model)
	entity:SetPos(record.position)
	entity:SetAngles(record.angles or angle_zero)
	entity:Spawn()

	--[[
		AFTER `Spawn`. A network variable set before it is silently lost - the
		entity has no network state to write into yet - which cost this project
		an afternoon on `SetBenchID`.
	]]
	entity.ixRecord = record
	entity.ixPointID = record.id
	record.entity = entity

	if (entity.OnRestored) then entity:OnRestored(record) end

	return entity
end

function ix.points.Add(client, typeID, position, angles, model)
	local pointType = ix.points.byID[typeID]

	if (not pointType) then return false, "That is not a point type." end
	if (not ix.points.loaded) then
		return false, "The point list has not loaded yet."
	end

	local id = ix.points.nextID

	ix.points.nextID = id + 1

	local record = {
		id = id,
		type = typeID,
		position = position,
		angles = angles or angle_zero,
		model = model ~= "" and model or pointType.model,
		data = table.Copy(pointType.defaults or {})
	}

	ix.points.stored[id] = record

	local entity = ix.points.Spawn(record)

	if (not IsValid(entity)) then
		ix.points.stored[id] = nil

		return false, "It would not spawn."
	end

	ix.points.Save()

	ix.log.Add(client, "pointAdd", pointType.name, tostring(position))

	return true, id
end

function ix.points.Remove(client, entity)
	if (not IsValid(entity)) then return false, "Nothing there." end

	local id = entity.ixPointID
	local record = id and ix.points.stored[id]

	if (not record) then return false, "That is not a placed point." end

	local pointType = ix.points.byID[record.type]

	ix.points.stored[id] = nil

	entity:Remove()

	ix.points.Save()

	ix.log.Add(client, "pointRemove", pointType and pointType.name or "?",
		tostring(record.position))

	return true
end

--[[
	Delete one by the id `/points` printed, whether or not it is standing there.

	`/pointdelete` has called this since the day it was written and it HAS
	NEVER EXISTED - the command threw "attempt to call field 'RemoveByID' (a
	nil value)" on every use. `ix.points.Remove` takes an entity, which is no
	help for the case the command is for: a point that is not in front of you,
	or a record whose entity is gone.

	THE ID MAY BE A STRING OR A NUMBER, and both have to work.

	`ix.data` goes through JSON, which has no integer keys, so a record saved
	under `[3]` comes back under `["3"]` - and `sv_points.lua` deliberately
	keeps whichever key it was given rather than converting, so a map's table
	can hold both after a session of placing points on top of loaded ones.
	Looking up only one of the two answers "that is not a placed point" for
	half the list.
]]
function ix.points.RemoveByID(client, id)
	if (not ix.points.loaded) then
		return false, "The point list has not loaded yet."
	end

	id = string.Trim(tostring(id or ""))

	if (id == "") then return false, "Which one? /points lists them." end

	--[[
		ORE NODES ARE LISTED HERE TOO, and are deleted here too.

		They are not points - they have their own tool, their own list and an
		ore registry that is edited in game - but "the thing I want to delete
		is not standing there any more" is the same problem the points solved,
		and somebody looking for the command to remove one is going to type
		`/points`. So the listing shows them as `ore:3` and this hands those
		ids straight to the mining library.
	]]
	local ore = string.match(id, "^ore:(.+)$")

	if (ore) then return ix.mining.RemoveByID(client, ore) end

	--- The string first, because that is what a loaded record is keyed by.
	local key = ix.points.stored[id] and id or nil

	if (not key) then
		local number = tonumber(id)

		if (number and ix.points.stored[number]) then key = number end
	end

	if (not key) then
		return false, string.format("There is no point %s. /points lists them.",
			id)
	end

	local record = ix.points.stored[key]
	local pointType = ix.points.byID[record.type]

	ix.points.stored[key] = nil

	--[[
		The entity may be absent and that is not a failure - a looted cap stash
		is a record with no entity, and it is exactly the thing somebody needs
		this command to delete.
	]]
	if (IsValid(record.entity)) then record.entity:Remove() end

	ix.points.Save()

	ix.log.Add(client, "pointRemove", pointType and pointType.name or "?",
		tostring(record.position))

	return true
end

--[[
	Write an entity's own state back into its record.

	Called by the entities when something worth keeping changes - a stash
	emptied, a flag taken - rather than on a timer, because those are rare and
	a timer would write the file every few seconds for nothing.
]]
function ix.points.Update(entity)
	if (not IsValid(entity) or not entity.ixRecord) then return end

	ix.points.Save()
end

--------------------------------------------------------------------------------
-- What is actually out there
--------------------------------------------------------------------------------

--[[
	Every placed point, its record and its live entity, side by side.

	Written after a cap stash paid out nothing and there were four equally
	plausible reasons - no record attached, no caps on the entity, the entity
	not solid so `Use` never fired, or the payout erroring before it landed.
	Printing all four costs one line each and settles it in one run, which is
	how everything else in this project has been settled.
]]
concommand.Add("fo_point_report", function(client)
	if (IsValid(client) and not ix.admin.Can(client, "point.edit")) then
		return
	end

	local accent, plain = Color(255, 200, 100), Color(200, 200, 200)
	local bad = Color(255, 120, 120)

	MsgC(accent, "\n-- points ----------------------------------------------\n")
	MsgC(plain, string.format("  loaded: %s   records: %d   ticks: %d   "
		.. "ripened: %d\n", tostring(ix.points.loaded),
		table.Count(ix.points.stored), ix.points.ticks, ix.points.ripened))

	for id, record in pairs(ix.points.stored) do
		local entity = record.entity
		local alive = IsValid(entity)

		MsgC(alive and plain or bad, string.format(
			"  %-6s %-12s entity %-6s solid %-6s record %s\n", tostring(id),
			tostring(record.type), alive and "yes" or "NO",
			alive and tostring(entity:GetSolid() ~= SOLID_NONE) or "-",
			alive and tostring(entity.ixRecord == record) or "-"))

		--[[
			THE RECORD, NOT THE ENTITY. A looted stash has no entity - that
			is the whole design now - so reading the amount off one would
			print nothing for exactly the stash somebody is asking about.
		]]
		if (record.type == "capstash") then
			local data = record.data or {}
			local due = tonumber(data.refillAt) or 0

			MsgC(plain, string.format("         remaining %s of %s, back "
				.. "in %ds\n", tostring(data.remaining),
				tostring(data.caps),
				due > 0 and math.max(due - os.time(), 0) or 0))
		end

		--[[
			A PLANT'S WHOLE STATE IN ONE LINE, because "it does not grow back"
			is four questions - is it picked, is there a deadline, has the
			deadline passed, and does the record the entity is reading match
			the one being saved - and guessing which of the four was wrong is
			what cost the first version of the regrow.
		]]
		if (record.type == "plant") then
			local data = record.data or {}
			local due = tonumber(data.refillAt) or 0

			MsgC(plain, string.format("         %s  picked %-5s  back in %s"
				.. "  respawn %ss  yield %s  xp %s\n",
				tostring(data.plant),
				alive and tostring(entity:GetPicked()) or "?",
				due > 0 and (math.max(due - os.time(), 0) .. "s") or "-",
				tostring(data.respawn), tostring(data.yield),
				tostring(data.xp)))
		end

		if (alive and record.type == "captureflag") then
			MsgC(plain, string.format("         progress %.2f  holder '%s'  "
				.. "contested %s\n", entity:GetProgress(),
				entity:GetHolderName(), tostring(entity:GetContested())))
		end
	end

	MsgC(accent, "\n")
end)

--------------------------------------------------------------------------------
-- Logs
--------------------------------------------------------------------------------

ix.log.AddType("pointAdd", function(client, name, position)
	return string.format("%s placed a %s at %s.", client:Name(), name,
		position)
end, FLAG_WARNING)

ix.log.AddType("pointRemove", function(client, name, position)
	return string.format("%s removed a %s at %s.", client:Name(), name,
		position)
end, FLAG_DANGER)

ix.log.AddType("pointLoot", function(client, amount)
	return string.format("%s looted %s from a cap stash.", client:Name(),
		amount)
end)

ix.log.AddType("pointCapture", function(client, name, holder)
	return string.format("%s captured '%s' for %s.", client:Name(), name,
		holder)
end, FLAG_WARNING)

--[[
	The wage a capture point pays.

	NIL CLIENT ON PURPOSE - nobody did this, the point did. `ix.log.Add` and
	`ix.adminlog.Write` both take that (`ix.log.Parse` checks `if (client)`,
	`Write` checks `IsValid`), so the formatter has to as well rather than
	assuming there is a name to print.
]]
ix.log.AddType("pointPayout", function(client, name, holder, amount, count)
	return string.format("'%s' paid %s to %d member(s) of %s.", name, amount,
		count, holder)
end)
