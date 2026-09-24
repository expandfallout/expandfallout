--[[
	A canister of water, for a crop plot.

	Phoenix's `farming_water`, with their model and their behaviour: it is used
	up. There is no half-empty canister and no refilling one at a river - it is
	a consumable a farm eats, which is what gives a farm a running cost.

	NOT DRINKABLE, deliberately. This schema has water items for that under
	`items/food/`; a canister that could be either would be the obvious thing to
	drink in an emergency and a farm nobody could keep stocked.
]]

ITEM.name = "Water Canister"
ITEM.description = "A sealed canister of water. Pour it into a crop plot."
ITEM.model = "models/models/fallout/nv_gsmetalbox01.mdl"
ITEM.category = "Junk"

ITEM.width = 1
ITEM.height = 1

--- What the plot looks for.
ITEM.isWaterCanister = true

--[[
	How much this one holds. Read by `ix.farming.Give`, which falls back to the
	config - so a bigger canister is a new item with a bigger number and no new
	code.
]]
ITEM.water = nil

ITEM.functions.Pour = {
	name = "Pour",
	icon = "icon16/paintcan.png",

	OnRun = function(item)
		local client = item.player

		if (not IsValid(client)) then return false end

		local plot = ix.farming.LookingAt(client)

		if (not plot) then
			client:Notify("You need to be looking at a crop plot.")

			return false
		end

		--[[
			`Give` consumes it on success, so this always returns false: a
			second removal here would be Helix taking an item that has already
			gone.
		]]
		ix.farming.Give(client, plot, item)

		return false
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player)
	end
}
