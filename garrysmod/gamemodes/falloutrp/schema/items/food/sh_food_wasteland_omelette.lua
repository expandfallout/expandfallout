ITEM.name = "Wasteland Omelette"
ITEM.description = "Whatever eggs were to hand, cooked together."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/wastelandomelette.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 34
ITEM.hydration = 0
ITEM.radiation = 0

ITEM.eatMeText = "eats Wasteland Omelette."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
