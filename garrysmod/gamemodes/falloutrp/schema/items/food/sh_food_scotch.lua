ITEM.name = "Scotch"
ITEM.description = "Older than the war, and it tastes it."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/drink/alcohol/whiskey02.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 2
ITEM.hydration = 12
ITEM.radiation = 0

ITEM.isAlcohol = true

ITEM.eatMeText = "drinks Scotch."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
