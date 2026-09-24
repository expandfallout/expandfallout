ITEM.name = "Nightstalker Egg"
ITEM.description = "Mottled and unpleasantly soft."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/nightstalkeregg.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 12
ITEM.hydration = 0
ITEM.radiation = 3

ITEM.eatMeText = "eats Nightstalker Egg."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
