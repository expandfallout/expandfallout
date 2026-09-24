ITEM.name = "Pork and Beans"

ITEM.description = "A can of pre-war pork and beans."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/porknbeans.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 17 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 3 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a can of Pork and Beans."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
