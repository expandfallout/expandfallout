ITEM.name = "Radscorpion Steak"
ITEM.description = "The tail is off. The rest is dinner."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/radscorpionsteak.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 38
ITEM.hydration = 0
ITEM.radiation = 1

ITEM.eatMeText = "eats Radscorpion Steak."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
