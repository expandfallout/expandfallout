ITEM.name = "Rum"
ITEM.description = "A strong alcoholic beverage."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/junk/rumbottle.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 13 -- How much sustenance this food item provides, 0-100.
ITEM.isAlcohol = true

ITEM.eatMeText = "chugs down a glass of Rum."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
