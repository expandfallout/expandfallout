ITEM.name = "Beer"
ITEM.description = "A bottle of Beer."
ITEM.category = "Food"
ITEM.model = "models/roadkill/fallout/clutter/food/beer.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 10 -- How much sustenance this food item provides, 0-100.
ITEM.isAlcohol = true

ITEM.eatMeText = "chugs a bottle of Beer."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end

ITEM.effectFunctions = {
    SERVER = function(item, client)
    end,
    CLIENT = function(item, client)
    end
}
