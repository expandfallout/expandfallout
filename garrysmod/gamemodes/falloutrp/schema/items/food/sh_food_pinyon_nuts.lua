ITEM.name = "Pinyon Nuts"
ITEM.description = "A pocketful of pine nuts."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/crops/pinyonnuts.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 10
ITEM.hydration = 4
ITEM.radiation = 1

ITEM.eatMeText = "eats Pinyon Nuts."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
