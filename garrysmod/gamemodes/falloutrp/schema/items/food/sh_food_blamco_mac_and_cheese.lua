ITEM.name = "Blamco Mac and Cheese"

ITEM.description = "A box of Blamco Mac and Cheese. Just add water!"
ITEM.category = "Food"
ITEM.model = "models/roadkill/fallout/clutter/junk/blanco.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 9 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 3 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a box of Blamco Mac and Cheese."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
