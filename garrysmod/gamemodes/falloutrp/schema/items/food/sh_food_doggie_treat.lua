ITEM.name = "Doggie Treat"
ITEM.description = "For the dog. Probably."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/doggietreat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 14
ITEM.hydration = 0
ITEM.radiation = 0

ITEM.eatMeText = "eats Doggie Treat."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
