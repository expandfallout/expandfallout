ITEM.name = "Honey Mesquite Pod"
ITEM.description = "Sweet pulp inside a dry pod."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/crops/honeymesquite.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 10
ITEM.hydration = 4
ITEM.radiation = 1

ITEM.eatMeText = "eats Honey Mesquite Pod."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
