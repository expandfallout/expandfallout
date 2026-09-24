ITEM.name = "Milk"
ITEM.description = "A glass of 'fresh' Milk."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/junk/milkbottle_empty.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 22 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 3 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "gulps down a glass of 'fresh' Milk."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end

ITEM.effectFunctions = {
    SERVER = function(item, client)
    end,
    CLIENT = function(item, client)
    end
}
