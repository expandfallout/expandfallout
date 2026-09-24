ITEM.name = "Funnel Cake"

ITEM.description = "A cult-classic cake that only has more of a zing due to the radiation."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/food/funnelcake.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 15 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 3 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "eats a Funnel Cake."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
