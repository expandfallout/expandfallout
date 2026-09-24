ITEM.name = "Ant Nog"
ITEM.description = "Thick, yellow, and made from ants."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/drink/antnog.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 5
ITEM.hydration = 25
ITEM.radiation = 1

ITEM.eatMeText = "drinks Ant Nog."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
