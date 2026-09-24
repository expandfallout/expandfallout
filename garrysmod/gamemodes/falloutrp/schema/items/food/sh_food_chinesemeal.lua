ITEM.name = "Succulent Chinese Meal"

ITEM.description = "This is Memocracy Manifest."
ITEM.category = "Food"
ITEM.model = "models/props_junk/garbage_takeoutcarton001a.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 20 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 0

ITEM.eatMeText = "eats a Succulent Chinese Meal."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_eating_food_chewy_0" .. math.random(2) .. ".mp3"
end
