ITEM.name = "Punga Fruit"
ITEM.description = "Fibrous tropical fruit, well out of its range."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/crops/pungafruit.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 10
ITEM.hydration = 4
ITEM.radiation = 1

ITEM.eatMeText = "eats Punga Fruit."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
