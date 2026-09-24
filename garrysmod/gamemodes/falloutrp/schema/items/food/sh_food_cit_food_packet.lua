ITEM.name = "C.I.T Food Packet"

ITEM.description = "Filled with essential nutrients that completely satisfy the body's daily nutritional needs."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/mre.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 100 -- How much sustenance this food item provides, 0-100.

ITEM.eatMeText = "eats a food packet."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
