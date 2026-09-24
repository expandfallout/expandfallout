ITEM.name = "NCR Ration Pack"

ITEM.description = "A small container filled with ediable rations."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/food/mre.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 50 -- How much sustenance this food item provides, 0-100.

ITEM.eatMeText = "eats an NCR Ration Pack."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
