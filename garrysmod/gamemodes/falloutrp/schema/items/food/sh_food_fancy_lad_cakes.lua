ITEM.name = "Fancy Lad Cakes"

ITEM.description = "A box of delicious tiny cakes."
ITEM.category = "Food"
ITEM.model = "models/roadkill/fallout/clutter/junk/fancyladysnacks.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 17 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 3 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a Fancy Lad Cake."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
