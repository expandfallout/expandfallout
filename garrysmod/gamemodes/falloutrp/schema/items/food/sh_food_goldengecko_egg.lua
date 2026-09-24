ITEM.name = "Golden Gecko Egg"
ITEM.description = "Pale gold, and rarer than the rest."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/goldengeckoegg.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 12
ITEM.hydration = 0
ITEM.radiation = 3

ITEM.eatMeText = "eats Golden Gecko Egg."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
