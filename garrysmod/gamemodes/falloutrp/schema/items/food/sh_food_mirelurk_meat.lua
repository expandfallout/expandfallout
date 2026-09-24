ITEM.name = "Mirelurk Meat"
ITEM.description = "Sweet white meat prised out of the shell."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/mirelurkmeat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 18
ITEM.hydration = 0
ITEM.radiation = 6

ITEM.eatMeText = "eats Mirelurk Meat."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
