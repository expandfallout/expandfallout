ITEM.name = "Nuka-Victory"
ITEM.description = "The rarest flavor of Nuka-Cola ever released. This beverage is one of the most rare you could possibly find. Drinking it would be incredibly stupid."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/drink/nukacola.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 100 -- How much sustenance this food item provides, 0-100.

ITEM.eatMeText = "gulps down a glass of Nuka-Victory."

ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end

ITEM.effectFunctions = {
    SERVER = function(item, client)
        client:falloutNotify("✚ The cold beverage refreshes & energizes you!", "phoenix/ui/nv/ui_popup_messagewindow.mp3")
    end,
    CLIENT = function(item, client)
    end
}
