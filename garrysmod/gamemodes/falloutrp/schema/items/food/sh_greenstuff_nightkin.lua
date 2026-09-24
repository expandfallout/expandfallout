ITEM.name = "F.E.V (Nightkin)"

ITEM.description = "A vial of the Forced Evolutionary Virus, nightkin. Drinking this substance is rumored to induce mutations."
ITEM.category = "Food"
ITEM.model = "models/models/enclave/fevcanister.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.sustenance = 1 -- How much sustenance this food item provides, 0-100.
ITEM.radiation = 0 -- How much radiation this food item provides, 0-100.

ITEM.eatMeText = "drinks some green stuff."

ITEM.effectFunctions = {
    SERVER = function(item, client)
        local char = client:GetCharacter()
        if not char then return end

        char:setRace("nightkin")
    end,
}

ITEM.useSound = function()
    return "phoenix/itm/npc_human_drinking_bottle_gulp_0" .. math.random(2) .. ".mp3"
end
