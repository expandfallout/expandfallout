ITEM.name = "Nukalurk Sushi"
ITEM.description = "It glows a little. That is the appeal."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/nukalurksushi.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Nukalurk Sushi."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
