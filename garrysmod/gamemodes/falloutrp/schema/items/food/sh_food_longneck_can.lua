ITEM.name = "Canned Sardines"
ITEM.description = "Oily little fish in a long tin."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/longneckcan.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 14
ITEM.hydration = 0
ITEM.radiation = 0

ITEM.eatMeText = "eats Canned Sardines."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
