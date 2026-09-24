ITEM.name = "Bottled Water"
ITEM.description = "Sealed, and nobody has opened it since."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/drink/water.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 0
ITEM.hydration = 40
ITEM.radiation = 0

ITEM.eatMeText = "drinks Bottled Water."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
