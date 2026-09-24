ITEM.name = "Corn"
ITEM.description = "Grown somewhere with water to spare."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/corn.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 10
ITEM.hydration = 4
ITEM.radiation = 1

ITEM.eatMeText = "eats Corn."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
