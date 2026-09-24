ITEM.name = "Deathclaw Egg"

ITEM.description = "A large egg laid by a Deathclaw."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/deathclawegg.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 50 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 1 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a whole Deathclaw Egg."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
