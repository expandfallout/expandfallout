ITEM.name = "Radscorpion Omelette"
ITEM.description = "Folded over and cooked hard."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/radscorpionomelette.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 34
ITEM.hydration = 0
ITEM.radiation = 0

ITEM.eatMeText = "eats Radscorpion Omelette."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
