ITEM.name = "Soylent Green"
ITEM.description = "The wrapper does not say what is in it."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/soylentgreen.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Soylent Green."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
