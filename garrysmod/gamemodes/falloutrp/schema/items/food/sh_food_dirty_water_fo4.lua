ITEM.name = "Murky Water"
ITEM.description = "Wet. That is the best that can be said."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/drink/dirtywater.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 0
ITEM.hydration = 35
ITEM.radiation = 9

ITEM.eatMeText = "drinks Murky Water."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
