ITEM.name = "Absinthe"
ITEM.description = "Green, bitter, and far too strong."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/drink/alcohol/absinthe.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 2
ITEM.hydration = 12
ITEM.radiation = 0

ITEM.isAlcohol = true

ITEM.eatMeText = "drinks Absinthe."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
