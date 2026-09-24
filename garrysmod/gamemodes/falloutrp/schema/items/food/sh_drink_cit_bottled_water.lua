ITEM.name = "C.I.T Purified Water"
ITEM.description = "A bottle of purified water."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/drink/water.mdl"
ITEM.skin = 1
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 100 -- How much sustenance this food item provides, 0-100.

ITEM.eatMeText = "gulps down a bottle of Purified Water."
ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
