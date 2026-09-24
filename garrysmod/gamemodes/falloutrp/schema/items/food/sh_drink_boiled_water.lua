ITEM.name = "Boiled Water"
ITEM.description = "A bottle of water, Boiled to kill the rads"
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/drink/water_dirty.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 35 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 1 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "gulps down a bottle of Boiled Water."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end

ITEM.effectFunctions = {
    SERVER = function(item, client)
    end,
    CLIENT = function(item, client)
    end
}
