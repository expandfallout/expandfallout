ITEM.name = "Nukalurk Roll"
ITEM.description = "Rolled around glowing mirelurk meat."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/nukalurkroll.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 48
ITEM.hydration = 6
ITEM.radiation = 0

ITEM.eatMeText = "eats Nukalurk Roll."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
