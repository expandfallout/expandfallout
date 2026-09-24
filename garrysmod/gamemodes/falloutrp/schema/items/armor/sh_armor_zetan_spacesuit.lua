ITEM.name = "Zetan Spacesuit"
ITEM.description = "A spacesuit work by the Zetans, designed for use in hostile environments."
ITEM.model = "models/models/fallout/alienbox.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill_fallout/player/zetan/defaultbody.mdl"
ITEM.maleModel = "models/roadkill_fallout/player/zetan/defaultbody.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {
    [0] = 4
}

ITEM.armorRace = {
    ["zetan"] = true
}

ITEM.resistance = 90
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false
ITEM.hasStealth = true

ITEM.faction = "Zetan"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = true
}

ITEM.OnEquip = function(item, client)
    ix.armor.GiveStealth(client)
    return true
end

ITEM.OnUnequip = function(item, client)
    ix.armor.SetStealth(client, false)
    return true
end

ITEM.requestStealth = function(item, client, toggle)
    local currentStealth = client:GetNW2Bool("nutArmorStealthMode", false)
    if currentStealth then return true end
    local char = client:GetCharacter()
    if not char then return false end
    -- check if the helmet they are wearing is stealth compatible.
    local currentWeapon = client:GetActiveWeapon()
    if IsValid(currentWeapon) then
        local class = currentWeapon:GetClass()
        if not ix.armor.validStealthWeapons[class] then
            client:Notify("You need to have your hands free to use stealth mode.")
            return false
        end
    end

    return true
end

function ITEM:OnLoadout()
    if not self:GetData("equipped") then return end
    local client = self.player
    if not IsValid(client) then return end
    if self.onEquip then
        self:OnEquip(client)
    end
end
