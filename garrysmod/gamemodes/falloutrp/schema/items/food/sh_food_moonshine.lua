ITEM.name = "Moonshine"
ITEM.description = "Distilled in a shed. It shows."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/drink/alcohol/moonshine.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 2
ITEM.hydration = 12
ITEM.radiation = 0

ITEM.isAlcohol = true

ITEM.eatMeText = "drinks Moonshine."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
