ITEM.name = "Banana Yucca Fruit"
ITEM.description = "Starchy and filling."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/crops/bananayucca.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 10
ITEM.hydration = 4
ITEM.radiation = 1

ITEM.eatMeText = "eats Banana Yucca Fruit."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
