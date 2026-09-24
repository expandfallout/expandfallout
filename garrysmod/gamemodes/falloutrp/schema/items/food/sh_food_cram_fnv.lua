ITEM.name = "Cram"
ITEM.description = "Salt, fat and defiance in a tin."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/cram.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 14
ITEM.hydration = 0
ITEM.radiation = 0

ITEM.eatMeText = "eats Cram."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
