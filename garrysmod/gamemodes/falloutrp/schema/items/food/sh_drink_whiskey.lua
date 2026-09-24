ITEM.name = "Whiskey"
ITEM.description = "A strong alcoholic beverage."
ITEM.category = "Food"
ITEM.model = "models/models/fallout/whiskeybottle.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 13 -- How much sustenance this food item provides, 0-100.
ITEM.isAlcohol = true

ITEM.eatMeText = "gulps down a glass of Whiskey."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
