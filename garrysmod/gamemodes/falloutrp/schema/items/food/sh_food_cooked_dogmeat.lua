ITEM.name = "Cooked Dog Meat"

ITEM.description = "A piece of perfectly cooked dog meat, tender and juicy."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/dogfood.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 20 -- How much sustenance this food item provides, 0-100.

ITEM.eatMeText = "eats a piece of cooked dog meat."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
