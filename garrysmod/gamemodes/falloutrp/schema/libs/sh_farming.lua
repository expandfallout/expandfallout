--[[
	Farming: crop plots, seeds, water.

	Phoenix's `farming` plugin, which is the other half of the plants - the wild
	ones you find, and these, which you grow. Theirs is four entities: a planter
	with nine slots, a seed you throw at it, a water canister you throw at it,
	and a crop that grows in it.

	WHAT THEIRS DOES, and this does the same:

	    nine slots         three by three, each holding one crop
	    water              drains while anything is planted, and NOTHING GROWS
	                       without it - that is the whole game of it
	    growth             0 to 100, and the crop's model scales as it goes
	    harvest            E on the plot takes every ripe crop at once
	    consumed           a seed and a canister are gone once used

	THREE THINGS ARE NOT THEIRS:

	    getting a seed in  theirs makes you deploy a seed ENTITY and physically
	                       shove it into the planter. Here you either Use the
	                       seed while looking at a plot, or drop it on one -
	                       both end up in the same function
	    a partial harvest  theirs refuses the whole harvest if your inventory
	                       cannot take all of it. This takes what fits and
	                       leaves the rest growing, because a full bag should
	                       cost you a trip rather than the crop
	    they can persist   theirs are ordinary props and are gone on a restart,
	                       and so are these by default. `farmPersist` keeps them
	                       - positions, water and every crop at the growth it
	                       had reached - for a server that wants standing farms
]]

ix.farming = ix.farming or {}

--- Three by three, which is Phoenix's and is what the planter model fits.
ix.farming.slots = 9

--[[
	WHETHER PLOTS SURVIVE A RESTART, and they do not by default.

	They used to, and it was my decision rather than a requested one: Phoenix's
	planters are ordinary props and are gone with the map, and a plot that
	outlives the session it was placed in is a box somebody has to go round and
	tidy up. Asked for twice, so the default is now off - a plot is a thing you
	put down for an evening.

	Turning it on keeps the whole save: positions, water and every crop at the
	growth it had reached.
]]
ix.config.Add("farmPersist", false,
	"Whether crop plots survive a server restart.", nil, {
	category = "Farming"
})

ix.config.Add("farmGrowTime", 200,
	"Seconds a watered crop takes to ripen.", nil, {
	data = {min = 10, max = 86400},
	category = "Farming"
})

ix.config.Add("farmYield", 3,
	"How many of the plant one ripe crop gives.", nil, {
	data = {min = 1, max = 20},
	category = "Farming"
})

ix.config.Add("farmXP", 1,
	"Experience for each ripe crop harvested.", nil, {
	data = {min = 0, max = 1000},
	category = "Farming"
})

ix.config.Add("farmWaterMax", 100,
	"How much water a plot holds.", nil, {
	data = {min = 1, max = 1000},
	category = "Farming"
})

ix.config.Add("farmWaterRefill", 25,
	"How much water one canister adds.", nil, {
	data = {min = 1, max = 1000},
	category = "Farming"
})

--[[
	Phoenix's drain works out at exactly this: `0.01 * planted * 0.5` every
	tenth of a second is `0.05 * planted` a second. Written as the per-second
	number it actually is, because a per-tenth-of-a-second figure is a number
	nobody can reason about.
]]
ix.config.Add("farmWaterDrain", 0.05,
	"Water used per second, for each crop planted.", nil, {
	data = {min = 0, max = 10, decimals = 2},
	category = "Farming"
})

--------------------------------------------------------------------------------
-- What a seed grows into
--------------------------------------------------------------------------------

--[[
	The world model for a growing crop, by the plant item it yields.

	MOST OF THESE ARE ALREADY KNOWN. `ix.plants.types` carries the world model
	for each of the seventeen wild plants and a growing crop is the same thing
	standing in a box, so that table is the source and this only names what it
	does not have: the four that are crops and never grow wild.

	Every path was checked with `resolve_asset.py`. Two of Phoenix's are not
	installed here - their carrot and tarberry are under
	`models/fallout/consumables/`, which this server does not have - so those
	two use the models the items themselves use.
]]
ix.farming.models = {
	plant_tato = "models/models/fallout/potatoplant.mdl",
	plant_mutfruit = "models/models/fallout/mutfruitvinea.mdl",
	plant_carrot = "models/mosi/fnv/props/food/crops/carrot.mdl",
	plant_tarberry = "models/mosi/fallout4/props/food/tarberry.mdl",
	plant_buffalogourd = "models/mosi/fnv/props/food/crops/buffalogourd.mdl"
}

--- Fallback for a seed whose plant has no model anywhere.
ix.farming.fallbackModel = "models/roadkill/fallout/clutter/plants/xanderroot.mdl"

function ix.farming.CropModel(uniqueID)
	if (ix.farming.models[uniqueID]) then return ix.farming.models[uniqueID] end

	for _, plant in ipairs(ix.plants and ix.plants.types or {}) do
		if (plant.item == uniqueID) then return plant.model end
	end

	return ix.farming.fallbackModel
end

--[[
	Where crop number `index` sits inside the plot, in the plot's own space.

	Phoenix's arithmetic, kept because it is fitted to the planter model rather
	than derived from anything: three rows of three, and the middle row sits
	higher because the soil in the model is not flat.
]]
function ix.farming.SlotOffset(index)
	local line = math.ceil(index / 3)
	local y = 20 * (index - (3 * line))
	local x = 40 * (line - 2)
	local z = 5

	if (line == 1) then
		z = 3
	elseif (line == 2) then
		z = 7
	end

	return Vector(x, y + 20, z)
end

--- Is this item a seed, and what does it grow?
function ix.farming.SeedType(item)
	if (not item or not item.isSeed) then return end

	return item.plantType
end
