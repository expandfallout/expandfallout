ITEM.name = "Sack of Flour"
ITEM.description = "Useless alone. Priceless to a cook."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/flour.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 14
ITEM.hydration = 0
ITEM.radiation = 0

ITEM.eatMeText = "eats Sack of Flour."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
