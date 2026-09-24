ITEM.name = "Steamed Radroach"
ITEM.description = "Somehow this is the appetising way to serve one."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/steamedradroach.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 38
ITEM.hydration = 0
ITEM.radiation = 1

ITEM.eatMeText = "eats Steamed Radroach."

ITEM.useSound = function()
	return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
