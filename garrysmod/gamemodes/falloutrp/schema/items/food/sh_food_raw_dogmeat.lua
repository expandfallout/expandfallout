ITEM.name = "Raw Dog Meat"

ITEM.description = "A piece of raw dog meat. It looks like it could be cooked to make a decent meal."
ITEM.category = "Food"
ITEM.model = "models/roadkill/fallout/clutter/food/dogmeat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 10 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 10 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a piece of raw dog meat."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
