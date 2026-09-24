ITEM.name = "Instant Noodles"
ITEM.description = "Two hundred years old and still edible."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/ramen.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Instant Noodles."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
