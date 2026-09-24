ITEM.name = "InstaMash"

ITEM.description = "Freeze-dried powdered mashed potatoes."
ITEM.category = "Food"
ITEM.model = "models/roadkill/fallout/clutter/junk/instamash.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 15 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 3 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a box of InstaMash."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
