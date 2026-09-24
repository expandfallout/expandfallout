ITEM.name = "Bloodworm Meat"
ITEM.description = "Rubbery and unpleasantly cold."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/bloodwormmeat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 18
ITEM.hydration = 0
ITEM.radiation = 6

ITEM.eatMeText = "eats Bloodworm Meat."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
