ITEM.name = "Mirelurk Roast"
ITEM.description = "A whole mirelurk, roasted in its shell."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/mirelurkroast.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Mirelurk Roast."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
