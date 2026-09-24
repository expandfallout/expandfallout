ITEM.name = "Mirelurk Special"
ITEM.description = "The house speciality, wherever the house is."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/mirelurkspecial.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Mirelurk Special."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
