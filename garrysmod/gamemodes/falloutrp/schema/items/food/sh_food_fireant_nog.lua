ITEM.name = "Fire Ant Nog"
ITEM.description = "It burns going down and keeps burning."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/drink/fireantnog.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 5
ITEM.hydration = 25
ITEM.radiation = 1

ITEM.eatMeText = "drinks Fire Ant Nog."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
