ITEM.name = "Securitron OS Executive Upgrade"

ITEM.description = "A chip upgrade software, and a fresh coat of paint."
ITEM.category = "Food"
ITEM.model = "models/mosi/fallout4/props/junk/circuitboard.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 1 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 0 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "downloads OS upgrade."

ITEM.effectFunctions = {
    SERVER = function(item, client)
        local char = client:GetCharacter()
        if not char then return end

        char:setRace("securitronexecutive")
    end,
}

ITEM.useSound = function()
    return "weapons/reload/rcw/wpn_laserrcw_reloadpt2" .. math.random(2) .. ".mp3"
end
