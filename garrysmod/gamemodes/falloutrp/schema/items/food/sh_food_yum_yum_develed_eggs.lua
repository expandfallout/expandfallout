ITEM.name = "Yum Yum Deviled Eggs"

ITEM.description = "A box of pre-war develed eggs."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/yumyumdeviledeggs.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 17 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 2 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a bowl of Yum Yum Deviled Eggs."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
