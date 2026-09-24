ITEM.name = "Spore Pod"
ITEM.description = "Cut from a spore carrier. Edible at a push."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/crops/sporepod.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 10
ITEM.hydration = 4
ITEM.radiation = 1

ITEM.eatMeText = "eats Spore Pod."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
