ITEM.name = "Mole Rat Stew"
ITEM.description = "Thick with meat and root vegetables."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/moleratstew.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Mole Rat Stew."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
