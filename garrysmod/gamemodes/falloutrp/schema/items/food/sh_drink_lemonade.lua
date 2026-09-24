ITEM.name = "Lemonade"
ITEM.description = "A bottle of refreshing Lemonade."
ITEM.category = "Food"
ITEM.model = "models/roadkill/fallout/clutter/food/waterbottlepurified.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 17 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 2 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "gulps down a bottle of Lemonade."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end

ITEM.effectFunctions = {
    SERVER = function(item, client)
    end,
    CLIENT = function(item, client)
    end
}
