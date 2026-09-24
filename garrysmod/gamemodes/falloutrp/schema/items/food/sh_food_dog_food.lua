ITEM.name = "Dog Food"

ITEM.description = "A can of Dog Food."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/dogfood.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 9 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 3 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a can of Dog Food."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
