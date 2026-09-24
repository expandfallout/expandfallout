ITEM.name = "Radroach Steak"
ITEM.description = "Roasted until the shell splits. Better than it sounds."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/radroachsteak.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 38
ITEM.hydration = 0
ITEM.radiation = 1

ITEM.eatMeText = "eats Radroach Steak."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
