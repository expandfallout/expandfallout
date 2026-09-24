--[[
	Plots: keeping them, growing them, and getting things into them.

	THE TICK IS ONE TIMER OVER EVERY PLOT, at one second - not Phoenix's timer
	per planter at a tenth of a second. Same result, a hundredth of the timers,
	and it is the shape this codebase already uses for every other wait (see
	`ix.points.Tick`).

	THEY ARE SAVED PER MAP. Phoenix's planters are ordinary props and vanish on
	a restart; a farm that has been watered for twenty minutes is not a prop.
	The save is the same pattern as the points - `LoadData`, a `PostLoadData`
	and a timer as belt and braces, and a SAVE GUARD so that a load which never
	ran cannot write an empty table over the file.
]]

if (not SERVER) then return end

util.AddNetworkString("ixFarmPlace")
util.AddNetworkString("ixFarmBeginPlacing")

ix.farming.plots = ix.farming.plots or {}
ix.farming.loaded = false

local KEY = "cropplots"

--------------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------------

--[[
	Everything a plot is, as plain values.

	The crops are written as `{item, growth}` per slot, keyed by the slot, so a
	plot comes back with the same crops in the same holes at the same size.
]]
local function Describe(plot)
	local crops = {}

	for slot, crop in pairs(plot.crops or {}) do
		if (not IsValid(crop)) then continue end

		crops[#crops + 1] = {
			slot = slot,
			item = crop:GetPlantID(),
			growth = math.Round(crop:GetGrowth(), 2)
		}
	end

	return {
		position = plot:GetPos(),
		angles = plot:GetAngles(),
		water = math.Round(plot:GetWater(), 2),
		owner = plot.ixOwner,
		crops = crops
	}
end

function ix.farming.Save()
	if (not ix.farming.loaded) then return end

	--[[
		NOTHING IS KEPT when plots are not meant to survive - and the file is
		emptied rather than left alone, or turning the setting off would leave
		yesterday's farm on disk waiting to come back the next time somebody
		turned it on.
	]]
	if (not ix.config.Get("farmPersist", false)) then
		ix.data.Set(KEY, {})

		return
	end

	local out = {}

	for _, plot in ipairs(ents.FindByClass("ix_cropplot")) do
		if (not IsValid(plot)) then continue end

		--[[
			SKIPPING ANYTHING ALREADY ON ITS WAY OUT, and this is the bug that
			brought removed plots back.

			`Entity:Remove` does not remove anything immediately - the entity
			goes at the END OF THE TICK - so `ents.FindByClass` a line later
			still returns it and `IsValid` is still true. Picking a plot up
			therefore removed it and then saved it, and it was standing there
			again after the next restart.

			`ixRemoved` is set by whatever asked for the removal, and the save
			below is deferred a tick as well - either alone would do, and both
			together mean a third way of removing one cannot reintroduce it.
		]]
		if (plot.ixRemoved) then continue end

		out[#out + 1] = Describe(plot)
	end

	ix.data.Set(KEY, out)
end

--[[
	Growth is saved on a timer as well as on every change.

	A change - planting, watering, harvesting - writes immediately, because
	those are the things somebody would be upset to lose. Growth moves every
	second and writing every second is absurd, so it goes down once a minute
	and on shutdown; the worst a crash costs is a minute of ripening.
]]
timer.Create("ixFarmingSave", 60, 0, function()
	if (not ix.farming.loaded) then return end
	if (#ents.FindByClass("ix_cropplot") == 0) then return end

	ix.farming.Save()
end)

hook.Add("SaveData", "ixFarming", function()
	ix.farming.Save()
end)

function ix.farming.Load()
	if (ix.farming.loaded) then return end

	ix.farming.loaded = true

	--[[
		A restart with persistence off starts empty, and clears what was there.
		The plots from the last session are not spawned and not kept.
	]]
	if (not ix.config.Get("farmPersist", false)) then
		ix.data.Set(KEY, {})

		return
	end

	local stored = ix.data.Get(KEY, {}) or {}
	local count = 0

	for _, record in ipairs(stored) do
		local plot = ents.Create("ix_cropplot")

		if (not IsValid(plot)) then continue end

		--[[
			VECTORS COME BACK AS PLAIN TABLES. `ix.data` is JSON, so a saved
			`Vector` returns as `{x, y, z}` with no metatable - the same trap
			the doors hit, and the reason both of these are converted rather
			than trusted.
		]]
		plot:SetPos(Vector(record.position))
		plot:SetAngles(Angle(record.angles))
		plot:Spawn()
		plot:Activate()

		plot.ixOwner = record.owner
		plot:SetWater(tonumber(record.water) or 0)

		for _, crop in ipairs(record.crops or {}) do
			plot:PlantSeed(crop.item, tonumber(crop.growth) or 0)
		end

		count = count + 1
	end

	if (count > 0) then
		MsgC(Color(255, 200, 100), string.format(
			"[falloutrp] %d crop plot(s) restored\n", count))
	end
end

hook.Add("LoadData", "ixFarming", ix.farming.Load)
hook.Add("PostLoadData", "ixFarming", ix.farming.Load)
timer.Simple(10, ix.farming.Load)

--------------------------------------------------------------------------------
-- Growing
--------------------------------------------------------------------------------

--[[
	One second of farming, everywhere.

	Two jobs, and the second one is not obvious: anything DROPPED on a plot is
	swept up here as well as by the plot's `StartTouch`. Two frozen physics
	props resting against each other do not reliably touch in the Source sense,
	so a seed placed carefully on the soil - which is exactly how somebody would
	do it - can sit there for ever waiting for a callback that has already
	happened or never will.
]]
timer.Create("ixFarmingTick", 1, 0, function()
	for _, plot in ipairs(ents.FindByClass("ix_cropplot")) do
		if (not IsValid(plot)) then continue end

		plot:Advance(1)

		--- Only worth sweeping while there is somewhere for it to go.
		for _, entity in ipairs(ents.FindInSphere(plot:GetPos(), 48)) do
			if (not IsValid(entity)) then continue end
			if (entity:GetClass() ~= "ix_item") then continue end

			ix.farming.AbsorbItem(plot, entity)
		end
	end
end)

--------------------------------------------------------------------------------
-- Getting a seed or a canister into one
--------------------------------------------------------------------------------

--[[
	The plot in front of somebody, or nothing.

	Ninety-six units, which is what E means everywhere else in this schema. Used
	by the seed and the canister so that "use it while looking at a plot" is the
	same reach as "press E on the plot".
]]
function ix.farming.LookingAt(client)
	if (not IsValid(client)) then return end

	local trace = util.TraceLine({
		start = client:GetShootPos(),
		endpos = client:GetShootPos() + client:GetAimVector() * 96,
		filter = client
	})

	local entity = trace.Entity

	if (not IsValid(entity)) then return end

	--- A crop is parented into a plot, so hitting one is hitting the plot.
	if (entity:GetClass() == "ix_crop") then entity = entity:GetParent() end

	if (not IsValid(entity) or entity:GetClass() ~= "ix_cropplot") then return end

	return entity
end

--[[
	Both ways in end up here.

	`item` is an item table with an instance behind it; the plot only cares
	about two questions - does it grow something, or is it water - and the
	answer to either consumes it.
]]
function ix.farming.Give(client, plot, item)
	if (not IsValid(plot) or not item) then return false end

	local seed = ix.farming.SeedType(item)

	if (seed) then
		local ok, why = plot:PlantSeed(seed)

		if (not ok) then
			if (IsValid(client) and why) then client:Notify(why) end

			return false
		end

		plot:EmitSound("phoenix/ui/nv/ui_items_generic_down.mp3", 60)

		if (IsValid(client)) then
			local grown = ix.item.list[seed]

			client:Notify(string.format("You plant the %s seeds.",
				grown and grown.name or "crop"))

			ix.log.Add(client, "farmPlant", seed)
		end

		item:Remove()

		return true
	end

	if (item.isWaterCanister) then
		local amount = item.water or ix.config.Get("farmWaterRefill", 25)
		local ok, why = plot:AddWater(amount)

		if (not ok) then
			if (IsValid(client) and why) then client:Notify(why) end

			return false
		end

		plot:EmitSound("phoenix/itm/npc_human_drinking_bottle_gulp_01.mp3", 65)

		if (IsValid(client)) then
			client:Notify("You water the plot.")

			ix.log.Add(client, "farmWater", tostring(math.Round(amount)))
		end

		item:Remove()

		return true
	end

	return false
end

--[[
	Using a plot while holding something.

	The plot asks this before it harvests: whatever is in your inventory that
	the plot wants goes in, and the seed nearest the front of the bag is the
	one used. Returns whether it took something, so `ENT:Use` knows not to
	harvest as well.
]]
function ix.farming.UseHeld(client, plot)
	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return false end

	local seed, water

	for item in ix.inventory.Each(inventory) do
		if (not seed and ix.farming.SeedType(item)) then seed = item end
		if (not water and item.isWaterCanister) then water = item end
	end

	--[[
		SEEDS FIRST, water second. A plot with room is usually a plot you are
		still filling, and somebody carrying both almost always means to plant.
		A full plot falls through to the water, which is the only other thing
		it can want.
	]]
	if (seed and plot:FreeSlot()) then
		return ix.farming.Give(client, plot, seed)
	end

	if (water) then return ix.farming.Give(client, plot, water) end

	return false
end

--[[
	A dropped item that touched a plot.

	`ix_item` carries the item table on `entity.ixItemID`; anything else on the
	map is not our business. The entity is removed by `item:Remove()` on the
	way through `Give`, which is what makes the seed disappear into the soil.
]]
function ix.farming.AbsorbItem(plot, entity)
	--[[
		THE INSTANCE, NOT THE DEFINITION. `ENT:GetItemTable` answers
		`ix.item.list[...]` - the shared table every zip tie in the game is -
		and calling `Remove` on that would be removing the item TYPE. The
		instance is what a dropped entity is holding, and it is the thing with
		an id, an inventory and a `Remove` worth calling.
	]]
	local item = ix.item.instances[entity.ixItemID or entity:GetItemID()]

	if (not item) then return false end
	if (not ix.farming.SeedType(item) and not item.isWaterCanister) then
		return false
	end

	--- Whoever dropped it, if they are still about, so the log has a name.
	local client = entity.ixDroppedBy

	if (not IsValid(client)) then client = nil end

	return ix.farming.Give(client, plot, item)
end

--[[
	Remembering who dropped something, purely so the notification and the log
	have somebody to name. Nothing depends on it.
]]
hook.Add("OnItemTransferred", "ixFarming", function(item, curInv, inventory)
	if (not inventory or inventory.GetID) then return end

	local entity = item.entity

	if (IsValid(entity) and IsValid(item.player)) then
		entity.ixDroppedBy = item.player
	end
end)

--------------------------------------------------------------------------------
-- Putting one down
--------------------------------------------------------------------------------

net.Receive("ixFarmPlace", function(length, client)
	local position = net.ReadVector()
	local angles = net.ReadAngle()

	local character = client:GetCharacter()
	local inventory = character and character:GetInventory()

	if (not inventory) then return end

	--[[
		THE ITEM IS FOUND AGAIN HERE rather than trusted from the message. The
		client says "I placed it there", not "I had one" - anything else is a
		free plot for anybody who can send a net message.
	]]
	local held

	for item in ix.inventory.Each(inventory) do
		if (item.isCropPlot) then
			held = item

			break
		end
	end

	if (not held) then return end

	local ok, why = ix.deploy.CanPlace(client, position)

	if (not ok) then
		client:Notify(why or "You cannot put it there.")

		return
	end

	local plot = ents.Create("ix_cropplot")

	if (not IsValid(plot)) then return end

	plot:SetPos(position)
	plot:SetAngles(Angle(0, angles.y, 0))
	plot:Spawn()
	plot:Activate()

	plot.ixOwner = character:GetID()

	held:Remove()

	ix.farming.Save()

	client:Notify("Plot placed. Put seeds in it and keep it watered.")

	ix.log.Add(client, "farmPlace", tostring(position))
end)

--[[
	Taking one back.

	The person who put it down, or anybody who may edit the map furniture. A
	plot with crops in it warns rather than refuses - somebody who wants their
	box back at the cost of what is growing in it is allowed to make that
	trade, and the notice tells them they are making it.
]]
function ix.farming.Remove(client, plot)
	if (not IsValid(plot)) then return false, "Nothing there." end

	local character = client:GetCharacter()

	if (not character) then return false end

	local owns = plot.ixOwner and plot.ixOwner == character:GetID()

	if (not owns and not ix.admin.Can(client, "point.edit")) then
		return false, "That is not yours."
	end

	local planted = plot:Planted()
	local inventory = character:GetInventory()

	if (inventory and not inventory:Add("cropplot")) then
		return false, "You have no room for it."
	end

	--- Marked before it is removed; see the note in `Save`.
	plot.ixRemoved = true

	plot:Remove()

	--[[
		A TICK LATER. The entity is genuinely gone by then, so the save writes
		what is actually standing on the map rather than what was standing on
		it a moment ago.
	]]
	timer.Simple(0, ix.farming.Save)

	ix.log.Add(client, "farmRemove", planted)

	return true, planted > 0
		and string.format("Picked it up. %d crop(s) lost.", planted)
		or "Picked it up."
end

ix.log.AddType("farmPlace", function(client, position)
	return string.format("%s placed a crop plot at %s.", client:Name(),
		position)
end)

ix.log.AddType("farmRemove", function(client, planted)
	return string.format("%s picked up a crop plot with %d crop(s) in it.",
		client:Name(), planted)
end)

ix.log.AddType("farmPlant", function(client, uniqueID)
	return string.format("%s planted %s.", client:Name(), uniqueID)
end)

ix.log.AddType("farmWater", function(client, amount)
	return string.format("%s watered a plot by %s.", client:Name(), amount)
end)

ix.log.AddType("farmHarvest", function(client, uniqueID, given)
	return string.format("%s harvested %d %s.", client:Name(), given, uniqueID)
end)
