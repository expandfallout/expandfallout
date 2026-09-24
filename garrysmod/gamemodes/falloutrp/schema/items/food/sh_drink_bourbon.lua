ITEM.name = "Bourbon"
ITEM.description = "A bottle of Bourbon."
ITEM.category = "Food"
ITEM.model = "models/roadkill/fallout/clutter/food/whiskeybottle02.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 13 -- How much sustenance this food item provides, 0-100.
ITEM.isAlcohol = true

ITEM.eatMeText = "chugs a bottle of Bourbon."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end

ITEM.effectFunctions = {
    SERVER = function(item, client)
    end,
    CLIENT = function(item, client)
    end
}
