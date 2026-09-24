ITEM.name = "Gecko Steak"
ITEM.description = "A Mojave staple, grilled over coals."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/geckosteak.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 38
ITEM.hydration = 0
ITEM.radiation = 1

ITEM.eatMeText = "eats Gecko Steak."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
