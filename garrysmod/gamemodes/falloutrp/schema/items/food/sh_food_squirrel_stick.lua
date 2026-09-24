ITEM.name = "Squirrel on a Stick"
ITEM.description = "Two squirrels, one stick."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/squirrelonastick.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 38
ITEM.hydration = 0
ITEM.radiation = 1

ITEM.eatMeText = "eats Squirrel on a Stick."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
