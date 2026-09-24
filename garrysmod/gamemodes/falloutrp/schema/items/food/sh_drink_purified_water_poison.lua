ITEM.name = "Purified Water"
ITEM.description = " A bottle of purified water."
ITEM.category = "Food"
ITEM.model = "models/roadkill/fallout/clutter/food/waterbottlepurified.mdl"
ITEM.width = 1
ITEM.height = 1

ITEM.hydration = 50 -- How much sustenance this food item provides, 0-100.

ITEM.eatMeText = "gulps down a bottle of Purified Water."
ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end

ITEM.effectFunctions = {
    SERVER = function(item, client)
        local deaths = client:Deaths()
        timer.Simple(30, function()
            if IsValid(client) and client:Deaths() > deaths then
                return
            end

            client:Kill()
            client:falloutNotify("☣ The purified water was poisoned!", "phoenix/ui/nv/ui_health_chems_wearoff.mp3")
        end)
    end,
    CLIENT = function(item, client)
    end
}
