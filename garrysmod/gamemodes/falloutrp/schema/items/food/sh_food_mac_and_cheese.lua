ITEM.name = "Mac and Cheese"
ITEM.description = "Orange, salty, and deeply comforting."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/macandcheese.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Mac and Cheese."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
