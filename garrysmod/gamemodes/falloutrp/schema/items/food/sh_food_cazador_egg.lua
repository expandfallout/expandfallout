ITEM.name = "Cazador Egg"
ITEM.description = "Whatever is inside is not finished yet."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/cazadoregg.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 12
ITEM.hydration = 0
ITEM.radiation = 3

ITEM.eatMeText = "eats Cazador Egg."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
