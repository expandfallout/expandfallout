--[[
	Persistent props.

	The well-known PermaProps addon, rebuilt against `ix.data` so it stores
	alongside everything else this schema persists rather than adding a second
	storage mechanism with its own folder.

	Marked props survive a restart, a map reload and a crash. Everything else
	on the map is still cleaned up as normal, which is the point - a server
	that persists everything fills up with test crates and dropped rubbish.

	PER MAP, like the lootables. A prop's position means nothing on a different
	map, and restoring `rp_utah`'s furniture onto `gm_construct` would drop it
	all through the floor.

	THE RECORD LIST IS AUTHORITATIVE, NOT THE ENTITIES.

	Saving by walking live entities looks obvious and is destructive in one
	specific way: a sandbox cleanup removes everything on the map, and the next
	save would then write an empty list and delete every permanent prop for
	good. So the list is kept here and the entities are a consequence of it. A
	prop leaves the save only when somebody makes it temporary or deletes it -
	which is what "permanent" has to mean.

	WHAT IS SAVED. Class, model, position, angles, skin, bodygroups, colour,
	material and whether it was frozen. That covers props, which is what this
	is for. A scripted entity is restored by CLASS ONLY - it comes back, but
	whatever internal state it held does not.
]]

if (not SERVER) then return end

ix.permaprop = ix.permaprop or {}

--- Records, each optionally linked to the live entity it produced.
ix.permaprop.stored = ix.permaprop.stored or {}

--[[
	Entities that must never be made persistent.

	`ix_lootable` has its own persistence and would otherwise be saved twice -
	restored once by each system, giving a duplicate on every restart.
]]
ix.permaprop.blacklist = {
	ix_lootable = true,
	--[[
		Handled by `sv_containerperma.lua` instead, which is why `Add` never
		reaches this check for one. Listed anyway so anything calling
		`CanPersist` directly gets the same answer.
	]]
	ix_container = true,
	player = true,
	predicted_viewmodel = true,
	gmod_hands = true,
	viewmodel = true,
	worldspawn = true
}

function ix.permaprop.CanPersist(entity)
	if (not IsValid(entity)) then return false, "nothing there" end

	local class = entity:GetClass()

	if (ix.permaprop.blacklist[class]) then
		return false, class .. " cannot be made persistent"
	end

	if (entity:IsPlayer() or entity:IsWeapon()) then
		return false, "that is not a prop"
	end

	--[[
		A dropped Helix item is a real inventory row wearing an entity. Saving
		the entity would restore a prop with no item behind it - a ghost the
		player can see and never pick up.
	]]
	if (class == "ix_item") then
		return false, "dropped items are inventory, not world content"
	end

	return true
end

--- Everything needed to rebuild one entity.
function ix.permaprop.Describe(entity)
	local colour = entity:GetColor()
	local physics = entity:GetPhysicsObject()
	local bodygroups = {}

	for _, group in ipairs(entity:GetBodyGroups() or {}) do
		bodygroups[group.id] = entity:GetBodygroup(group.id)
	end

	return {
		class = entity:GetClass(),
		model = entity:GetModel(),
		position = entity:GetPos(),
		angles = entity:GetAngles(),
		skin = entity:GetSkin() or 0,
		bodygroups = bodygroups,
		colour = {colour.r, colour.g, colour.b, colour.a},
		material = entity:GetMaterial() or "",
		--[[
			Frozen state is worth keeping: a permanent prop is usually scenery,
			and one that comes back unfrozen falls over or gets pushed around by
			the first player to walk into it.
		]]
		frozen = IsValid(physics) and not physics:IsMotionEnabled() or false
	}
end

--[[
	Write the list, refreshing the transform of anything still alive.

	A prop dragged somewhere with the physgun saves where it was left; one a
	cleanup removed keeps its last known position and comes back there.
]]
function ix.permaprop.Save()
	--[[
		Same guard as the loot tables, for the same reason: if the load never
		ran, `stored` is empty and this would write that emptiness over the
		file. See `sv_loot.lua`.
	]]
	if (not ix.permaprop.loaded) then
		ErrorNoHalt("[falloutrp] refusing to save permanent props - they were " ..
			"never loaded, and saving now would erase them\n")

		return 0
	end

	local saved = {}

	for _, record in ipairs(ix.permaprop.stored) do
		if (IsValid(record.entity)) then
			local fresh = ix.permaprop.Describe(record.entity)

			for key, value in pairs(fresh) do
				record[key] = value
			end
		end

		--[[
			The live entity reference is stripped from what is written - it is
			a runtime link, and `util.TableToJSON` cannot encode an entity.
		]]
		local copy = table.Copy(record)

		copy.entity = nil
		saved[#saved + 1] = copy
	end

	ix.data.Set("permaprops", saved)

	return #saved
end

function ix.permaprop.Add(entity)
	--[[
		A storage container is permanent through HELIX, not through this list.

		Restoring one from here would rebuild the prop and not the inventory
		behind it - a container that opens empty every restart, with the real
		one still sitting in the database. So the mark is recorded against its
		inventory ID and Helix does the restoring, exactly as it already does.
		See `sv_containerperma.lua`.
	]]
	if (ix.permaprop.IsContainer(entity)) then
		return ix.permaprop.SetContainerPermanent(entity, true)
	end

	local ok, reason = ix.permaprop.CanPersist(entity)

	if (not ok) then return false, reason end

	if (entity.ixPerma) then return false, "already persistent" end

	local record = ix.permaprop.Describe(entity)

	record.entity = entity
	entity.ixPerma = record

	ix.permaprop.stored[#ix.permaprop.stored + 1] = record
	ix.permaprop.Save()

	return true
end

--[[
	The only path that shrinks the list. Everything else - a cleanup, a crash,
	a map change - leaves the record alone so the prop comes back.
]]
function ix.permaprop.Remove(entity)
	if (ix.permaprop.IsContainer(entity)) then
		return ix.permaprop.SetContainerPermanent(entity, false)
	end

	if (not IsValid(entity) or not entity.ixPerma) then
		return false, "that is not persistent"
	end

	for index, record in ipairs(ix.permaprop.stored) do
		if (record.entity == entity) then
			table.remove(ix.permaprop.stored, index)
			break
		end
	end

	entity.ixPerma = nil
	ix.permaprop.Save()

	return true
end

--[[
	Rebuild one saved entity.

	Deliberately tolerant: an entity whose class or model no longer exists is
	skipped and counted rather than taking the restore down with it. Losing one
	prop because a content pack was removed should not cost the other two
	hundred.
]]
function ix.permaprop.Restore(data)
	if (not data.class) then return false end

	--[[
		Props are created by class directly; anything else has to be a
		registered scripted entity. Creating an unknown class produces a broken
		entity rather than a missing one, which is harder to notice.
	]]
	if (not string.StartWith(data.class, "prop_")
	and not scripted_ents.GetStored(data.class)) then
		return false
	end

	if (data.model and data.model ~= "" and not util.IsValidModel(data.model)) then
		return false
	end

	local entity = ents.Create(data.class)

	if (not IsValid(entity)) then return false end

	if (data.model and data.model ~= "") then
		entity:SetModel(data.model)
	end

	entity:SetPos(data.position or vector_origin)
	entity:SetAngles(data.angles or angle_zero)
	entity:Spawn()
	entity:Activate()

	entity:SetSkin(data.skin or 0)

	for id, value in pairs(data.bodygroups or {}) do
		entity:SetBodygroup(tonumber(id) or 0, value)
	end

	if (data.colour) then
		entity:SetColor(Color(data.colour[1] or 255, data.colour[2] or 255,
			data.colour[3] or 255, data.colour[4] or 255))
	end

	if (data.material and data.material ~= "") then
		entity:SetMaterial(data.material)
	end

	local physics = entity:GetPhysicsObject()

	if (IsValid(physics) and data.frozen) then
		physics:EnableMotion(false)
		physics:Sleep()
	end

	--[[
		Linked back to the record it came from, so a later save refreshes this
		prop's transform rather than rewriting the position it was first
		marked at.
	]]
	data.entity = entity
	entity.ixPerma = data

	return true
end

function ix.permaprop.Load()
	ix.permaprop.stored = ix.data.Get("permaprops", {}) or {}

	local restored, failed = 0, 0

	for _, data in ipairs(ix.permaprop.stored) do
		if (ix.permaprop.Restore(data)) then
			restored = restored + 1
		else
			failed = failed + 1
		end
	end

	return restored, failed
end

--[[
	Restored a second after the world exists, matching the lootables. Both wait
	because spawning entities into a map that has not finished loading gets
	them removed again.
]]
--[[
	`LoadData`, not `InitPostEntity` - the latter does not reach this schema.
	See the note in `sv_loot.lua`. Helix runs `LoadData` after the database
	connects and again after a map cleanup, which is when world content should
	come back.
]]
ix.permaprop.loaded = ix.permaprop.loaded or false

local function LoadProps()
	if (ix.permaprop.loaded) then return end

	ix.permaprop.loaded = true

	local restored, failed = ix.permaprop.Load()

	MsgC(Color(255, 200, 100), string.format(
		"[falloutrp] restored %d permanent prop(s)%s\n", restored,
		failed > 0 and string.format(", %d could not be rebuilt", failed) or ""))
end

hook.Add("LoadData", "ixPermaProp", LoadProps)

hook.Add("InitPostEntity", "ixPermaProp", function()
	timer.Simple(2, LoadProps)
end)

--[[
	LAST RESORT.

	Two triggers is not belt and braces when both are hooks and this has now
	silently destroyed data twice by not running. A plain timer depends on
	nothing but the server ticking, and it is a no-op in every case where
	either hook did fire, because the load is guarded.

	Ten seconds is late enough that the database has certainly answered and
	early enough that nobody has finished connecting.
]]
timer.Simple(10, LoadProps)

--[[
	A cleanup removes permanent props like anything else; the records are what
	make them permanent, so they are simply built again.
]]
hook.Add("PostCleanupMap", "ixPermaProp", function()
	if (not ix.permaprop.loaded) then return end

	local restored = 0

	for _, record in ipairs(ix.permaprop.stored) do
		if (not IsValid(record.entity) and ix.permaprop.Restore(record)) then
			restored = restored + 1
		end
	end

	if (restored > 0) then
		MsgC(Color(255, 200, 100), string.format(
			"[falloutrp] put %d permanent prop(s) back after a cleanup\n",
			restored))
	end
end)

--[[
	Saved on shutdown as well as on change.

	Marking a prop saves immediately, but MOVING one does not - and a permanent
	prop dragged somewhere should come back where it was left, not where it was
	first marked. `ShutDown` runs on a clean stop or a map change; a hard crash
	still loses whatever moved since the last explicit save, which is the
	honest limit of doing this without a periodic write.
]]
hook.Add("ShutDown", "ixPermaProp", function()
	ix.permaprop.Save()
end)

concommand.Add("fo_permaprops", function(client)
	if (IsValid(client) and not client:IsSuperAdmin()) then return end

	--[[
		PRINTED TO WHOEVER RAN IT, not only to the server console.

		This used `MsgC` alone, which on a dedicated server goes to the window
		the server is running in - so a superadmin typing `fo_permaprops` in
		game saw absolutely nothing and reasonably concluded the perma props
		were gone. `fo_containers` beside it had the right shape all along and
		this did not.

		Both, rather than one: the server console is where you look when
		something has gone wrong at boot, and chat is where you look when you
		are standing next to the prop.
	]]
	local function Line(colour, text)
		if (IsValid(client)) then client:ChatPrint(text) end

		MsgC(colour, text .. "\n")
	end

	local counts = {}
	local total, missing = 0, 0

	--[[
		Counted from the RECORDS, so a prop a cleanup removed still shows up -
		it is still permanent, it is just not currently in the world, and
		hiding that would make this list disagree with what comes back on
		restart.
	]]
	for _, record in ipairs(ix.permaprop.stored) do
		local class = record.class or "?"

		counts[class] = (counts[class] or 0) + 1
		total = total + 1

		if (not IsValid(record.entity)) then missing = missing + 1 end
	end

	Line(Color(255, 200, 100), string.format(
		"[falloutrp] %d permanent prop(s) on %s", total, game.GetMap()))

	for class, count in SortedPairs(counts) do
		Line(Color(200, 200, 200), string.format("  %-32s %d", class, count))
	end

	if (missing > 0) then
		Line(Color(255, 160, 160), string.format(
			"  %d recorded but not in the world - they return on restart", missing))
	end

	--[[
		Counted separately because they are stored separately - and because
		"why has my crate gone" is nearly always a container that was never
		marked, which a list of props alone would not answer.
	]]
	local containers = 0

	for _ in pairs(ix.permaprop.containers or {}) do
		containers = containers + 1
	end

	Line(Color(255, 200, 100), string.format(
		"[falloutrp] %d permanent storage container(s), %d on the map",
		containers, #ents.FindByClass("ix_container")))
end)
