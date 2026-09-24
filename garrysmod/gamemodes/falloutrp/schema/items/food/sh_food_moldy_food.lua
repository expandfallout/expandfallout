ITEM.name = "Moldy Food"

ITEM.description = "It's so moldy and gross, we don't even know what it was."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/moldyfood.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 5 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 15 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats Moldy Food."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
