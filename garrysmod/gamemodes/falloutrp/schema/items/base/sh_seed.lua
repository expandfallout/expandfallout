--[[
	Seed base item.

	Seventeen bags of seeds, one per crop, and NONE OF THEM DO ANYTHING YET.
	That is deliberate and it is the whole of this file's design.

	WHY THEY EXIST NOW. Phoenix's seeds belong to their `farming` plugin: a seed
	is deployed into a planter, watered, grows on a timer and is harvested. That
	is four entities (`nut_farm_planter`, `nut_farm_seed`, `nut_farm_plant`,
	`nut_farm_water`), a water economy and a growth clock - a system of its own,
	and a later job.

	The seeds are here anyway because they are DATA, not behaviour: which crops
	exist, what each one grows into and what it is called. That list is needed
	by loot tables, by vendors and by the plants that already exist, and having
	it settled means the farming system arrives as a set of entities rather than
	as a set of entities AND thirty-four items nobody has checked.

	`plantType` is the whole contract. A seed says which item it eventually
	yields, and the farming system - when it exists - reads that and nothing
	else about the seed.
]]

ITEM.name = "Seeds"
ITEM.description = "A bag of seeds. Something to plant, once there is "
	.. "somewhere to plant it."
ITEM.model = "models/mosi/fnv/props/junk/seedbag.mdl"
ITEM.category = "Plants"

ITEM.width = 1
ITEM.height = 1

--- The marker the farming system will look for, rather than a base name.
ITEM.isSeed = true

--- The uniqueID of the plant item this grows. Set by every seed.
ITEM.plantType = nil

--[[
	PLANTING, which is one of the two ways a seed gets into a plot.

	The other is dropping it on one - `ix_cropplot:StartTouch` - and both end up
	in `ix.farming.Give`, so a seed cannot behave differently depending on how
	it was put in.

	This used to say there were deliberately no functions at all, because the
	farming system did not exist yet. It does now.
]]
ITEM.functions.Plant = {
	name = "Plant",
	icon = "icon16/shape_square_add.png",

	OnRun = function(item)
		local client = item.player

		if (not IsValid(client)) then return false end

		local plot = ix.farming.LookingAt(client)

		if (not plot) then
			client:Notify("You need to be looking at a crop plot.")

			return false
		end

		--[[
			`Give` removes the seed itself when it takes, so this returns false
			either way - returning true would have Helix remove an item that is
			either already gone or was never used.
		]]
		ix.farming.Give(client, plot, item)

		return false
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player)
			and item.plantType ~= nil
	end
}

--[[
	The description says what it grows, which is the only thing anybody needs
	from a bag of seeds.
]]
function ITEM:GetDescription()
	local description = self.description
	local grown = self.plantType and ix.item.list[self.plantType]

	if (grown) then
		description = description .. "\n\n - Grows: " .. grown.name
	end

	return description
end
