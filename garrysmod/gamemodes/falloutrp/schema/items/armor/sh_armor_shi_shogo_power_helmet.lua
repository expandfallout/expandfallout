ITEM.name = "Shi Shogo Stealth Power Helmet"
ITEM.description = "A set of Stealth Shogo Power helmet used by the Shi."
ITEM.model = "models/fallout/apparel/power_armor_helmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/shi_shogo_pa_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/shi_shogo_pa_helmet.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 85
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false
ITEM.hasStealth = false

ITEM.faction = "shi"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    ix.armor.SetStealth(client, false)
    return true
end
