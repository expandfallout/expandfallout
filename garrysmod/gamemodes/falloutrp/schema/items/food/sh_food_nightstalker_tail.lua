ITEM.name = "Nightstalker Tail"
ITEM.description = "Rattle and all."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/nightstalkertail.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 18
ITEM.hydration = 0
ITEM.radiation = 6

ITEM.eatMeText = "eats Nightstalker Tail."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
