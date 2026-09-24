ITEM.name = "Buzz Bites"

ITEM.description = "A delicious box of Donut Bites."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/slocumsbuzzbites.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 20 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 3 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a piece of Buzz Bites."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
