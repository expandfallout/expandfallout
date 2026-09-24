ITEM.name = "Lunchbox Meal"
ITEM.description = "Someone packed this two centuries ago."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/lunchbox_meal.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Lunchbox Meal."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
