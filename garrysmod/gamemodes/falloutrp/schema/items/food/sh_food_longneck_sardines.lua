ITEM.name = "Longneck Sardines"

ITEM.description = "A can of pre-war sardines."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/junk/cementbag.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 10 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 2 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a can of Longneck Sardines."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
