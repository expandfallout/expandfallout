ITEM.name = "Dandy Boy Apples"
ITEM.description = "Apple-flavoured, apple-adjacent."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/dandyboyapples.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 14
ITEM.hydration = 0
ITEM.radiation = 0

ITEM.eatMeText = "eats Dandy Boy Apples."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
