ITEM.name = "Perfectly Preserved Pie"

ITEM.description = "A perfectly preserved pie. It looks like it could be eaten right away."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/preservedpie.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 100 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 100 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a perfectly preserved pie."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
