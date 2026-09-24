ITEM.name = "Chewing Gum"
ITEM.description = "Flavour lasts eleven seconds."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/bubblegum.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 14
ITEM.hydration = 0
ITEM.radiation = 0

ITEM.eatMeText = "eats Chewing Gum."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
