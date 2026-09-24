ITEM.name = "Salisbury Steak"

ITEM.description = "A box of ancient but still delicious salisbury steak."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/salisburysteak.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 20 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 5 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a Salisbury Steak."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
