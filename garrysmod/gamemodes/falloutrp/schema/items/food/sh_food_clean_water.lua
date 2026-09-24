ITEM.name = "Clean Water"
ITEM.description = "Filtered, boiled, and worth carrying."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/drink/water_clean.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 0
ITEM.hydration = 40
ITEM.radiation = 0

ITEM.eatMeText = "drinks Clean Water."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
