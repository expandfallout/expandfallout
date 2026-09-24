ITEM.name = "Nuka-Fusion"
ITEM.description = "The unique taste of Nuka-Fusion is the result of a combination of seventeen fruit essences, balanced to enhance the classic cola flavor."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/drink/nukacola.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 20 -- How much sustenance this food item provides, 0-100.

ITEM.eatMeText = "gulps down a glass of Nuka-Fusion."

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
