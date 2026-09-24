ITEM.name = "Lemonade"
ITEM.description = "Sharp and startlingly sweet."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/drink/lemonade.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 5
ITEM.hydration = 25
ITEM.radiation = 1

ITEM.eatMeText = "drinks Lemonade."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
