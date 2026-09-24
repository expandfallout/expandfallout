ITEM.name = "Wasteland Hotdog"
ITEM.description = "In a bun, against the odds."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/wastelandhotdog.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Wasteland Hotdog."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
