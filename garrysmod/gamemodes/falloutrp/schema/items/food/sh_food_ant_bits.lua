ITEM.name = "Ant Bits"
ITEM.description = "Broken carapace and the meat inside it."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/antbits.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 18
ITEM.hydration = 0
ITEM.radiation = 6

ITEM.eatMeText = "eats Ant Bits."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
