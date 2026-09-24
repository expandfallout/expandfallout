ITEM.name = "Atomic Cocktail"
ITEM.description = "Mixed for people who expect to be looked at."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/drink/alcohol/atomiccocktail.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 2
ITEM.hydration = 12
ITEM.radiation = 0

ITEM.isAlcohol = true

ITEM.eatMeText = "drinks Atomic Cocktail."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
