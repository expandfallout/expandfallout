ITEM.name = "Sunset Sarsaparilla"
ITEM.description = "Sunset Sarsaparilla is a root-beer-type carbonated beverage."
ITEM.category = "Food"
ITEM.model = "models/roadkill/fallout/clutter/junk/sunsetsarsaprilla.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 20 -- How much sustenance this food item provides, 0-100.

ITEM.eatMeText = "gulps down a glass of Sunset Sarsaparilla."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
