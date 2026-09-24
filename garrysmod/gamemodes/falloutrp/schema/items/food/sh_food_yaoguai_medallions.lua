ITEM.name = "Yao Guai Medallions"
ITEM.description = "Trimmed, seared, and worth the fight."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/yaoguaimedallions.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 38
ITEM.hydration = 0
ITEM.radiation = 1

ITEM.eatMeText = "eats Yao Guai Medallions."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
