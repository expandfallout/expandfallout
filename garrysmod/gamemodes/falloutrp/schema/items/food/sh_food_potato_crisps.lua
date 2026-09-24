ITEM.name = "Potato Crisps"

ITEM.description = "A bag of crunchy potato crisps."
ITEM.category = "Food"
ITEM.model = "models/roadkill/fallout/clutter/junk/potatocrisps.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 8 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 2 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a bag of Potato Crisps."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
