ITEM.name = "White Horsenettle Berries"
ITEM.description = "Eat a few. Not a handful."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/crops/whitehorsenettleberries.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 10
ITEM.hydration = 4
ITEM.radiation = 1

ITEM.eatMeText = "eats White Horsenettle Berries."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
