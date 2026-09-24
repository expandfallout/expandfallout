ITEM.name = "Shi Shogo Stealth Power Armor"
ITEM.description = "A set of Stealth Shogo Power armor used by the Shi."
ITEM.model = "models/fallout/apparel/t51bpowerarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/shi_shogo_pa.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/shi_shogo_pa.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 85
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false
ITEM.hasStealth = false

ITEM.faction = "shi"

ITEM.specialBonus = {
	intelligence = 4
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
    -- check if the helmet they are wearing is stealth compatible.
    local helmet = char:GetData("equippedArmor:helmet", false) or char:GetData("equippedArmor:hat", false)
    local errorMsg = "You need to be wearing a stealth compatible helmet to use stealth mode."

    if not helmet then
        client:Notify(errorMsg)
        return false
    end

    if not ix.item.list[helmet] or not ix.item.list[helmet].hasStealth then
        client:Notify(errorMsg)
        return false
    end

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
