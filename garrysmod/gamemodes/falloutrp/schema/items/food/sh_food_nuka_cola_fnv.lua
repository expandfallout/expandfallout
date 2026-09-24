ITEM.name = "Nuka-Cola"
ITEM.description = "The original formula, still fizzing."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/drink/nukacola.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 5
ITEM.hydration = 25
ITEM.radiation = 1

ITEM.eatMeText = "drinks Nuka-Cola."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
