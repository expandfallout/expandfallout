ITEM.name = "Aged Whiskey"
ITEM.description = "A good bottle, kept for a reason."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/drink/alcohol/whiskey03.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 2
ITEM.hydration = 12
ITEM.radiation = 0

ITEM.isAlcohol = true

ITEM.eatMeText = "drinks Aged Whiskey."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
