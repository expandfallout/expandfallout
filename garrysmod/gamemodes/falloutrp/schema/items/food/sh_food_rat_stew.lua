ITEM.name = "Rat Stew"
ITEM.description = "Hot, filling, and best not examined."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/ratstew.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Rat Stew."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
