ITEM.name = "Strange Meat"
ITEM.description = "Nobody has said what it came from, and nobody has asked."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/meat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 18
ITEM.hydration = 0
ITEM.radiation = 6

ITEM.eatMeText = "eats Strange Meat."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
