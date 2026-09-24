ITEM.name = "Fire Ant Egg"
ITEM.description = "Hot to the touch."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/fireantegg.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 12
ITEM.hydration = 0
ITEM.radiation = 3

ITEM.eatMeText = "eats Fire Ant Egg."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
