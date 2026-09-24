ITEM.name = "Desert Salad"
ITEM.description = "Cactus fruit and mesquite, cut together."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/desertsalad.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Desert Salad."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
