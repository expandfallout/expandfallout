ITEM.name = "Nuka-Cola Quantum"
ITEM.description = "Twice the calories, twice the carbohydrates, twice the caffeine and twice the taste of regular Nuka-Cola."
ITEM.category = "Food"
ITEM.model = "models/mosi/fnv/props/drink/nukacola_quantum.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 20 -- How much sustenance this food item provides, 0-100.

ITEM.eatMeText = "gulps down a glass of Nuka-Cola Quantum."

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
