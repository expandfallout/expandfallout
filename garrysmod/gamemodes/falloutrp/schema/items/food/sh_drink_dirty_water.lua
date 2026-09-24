ITEM.name = "Dirty Water"
ITEM.description = "A bottle of Dirty Water. Drink at your own risk."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/drink/dirtywater.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 13 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 4 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "gulps down a bottle of Dirty Water."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end

ITEM.effectFunctions = {
    SERVER = function(item, client)
    end,
    CLIENT = function(item, client)
    end
}
