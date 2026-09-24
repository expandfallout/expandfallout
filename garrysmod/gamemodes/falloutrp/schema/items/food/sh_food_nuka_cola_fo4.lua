ITEM.name = "Nuka-Cola Bottle"
ITEM.description = "Ice cold, two hundred years ago."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/drink/nukacola2.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 5
ITEM.hydration = 25
ITEM.radiation = 1

ITEM.eatMeText = "drinks Nuka-Cola Bottle."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
