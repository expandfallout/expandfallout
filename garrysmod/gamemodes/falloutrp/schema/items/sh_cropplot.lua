--[[
	A crop plot, in a box.

	Phoenix's planter is an admin-spawned prop; this is a deployable, which is
	what was asked for and is also the only way a player-run farm makes sense -
	somebody has to be able to buy one, carry it and put it somewhere they can
	defend.

	Placing it uses the same ghost as the workbenches: the item asks the server,
	the server asks the client to start placing, and the client sends back where
	it ended up. The item is consumed by the SERVER when the plot is actually
	created, never here - a placement that is refused for being in a wall must
	not cost you the plot.
]]

ITEM.name = "Crop Plot"
ITEM.description = "A planter box with room for nine crops. Put it down, "
	.. "fill it with seeds, and keep it watered."
ITEM.model = "models/fallout/plot/planter.mdl"
ITEM.category = "Junk"

ITEM.width = 2
ITEM.height = 2

--- What `ixFarmPlace` looks for when it checks you actually had one.
ITEM.isCropPlot = true

ITEM.functions.Place = {
	name = "Place",
	icon = "icon16/shape_square_add.png",

	OnRun = function(item)
		local client = item.player

		if (not IsValid(client)) then return false end

		net.Start("ixFarmBeginPlacing")
			net.WriteString(item.model)
		net.Send(client)

		--- False: the item goes when the plot exists, not when you aim at the floor.
		return false
	end,

	OnCanRun = function(item)
		return not IsValid(item.entity) and IsValid(item.player)
	end
}
