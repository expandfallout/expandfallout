ITEM.name = "C.I.T Agent Leather Armor"
ITEM.description = "An advanced leather suit."
ITEM.model = "models/fallout/apparel/wastelandmerchant01.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false
ITEM.hasStealth = true
ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/coursercoat.mdl"
ITEM.maleModel = "models/galang/fallout/player/coursercoat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.faction = "C.I.T"

ITEM.resistance = 70
ITEM.speedBoost = 25
ITEM.jumpBoost = 0
ITEM.radResistance = 50
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	intelligence = 4,
	luck = 4
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = false,
    beard = false,
    head = false
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
