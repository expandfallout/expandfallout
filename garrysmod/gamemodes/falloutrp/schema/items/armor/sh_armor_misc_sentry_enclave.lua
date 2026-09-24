ITEM.name = "Sentry MK 1 Enclave Paint Coat"
ITEM.description = "A set of paint to designate a sentrybot as Enclave property."
ITEM.model = "models/mosi/fallout4/props/junk/mrhandyfuel.mdl"

ITEM.width = 3	
ITEM.height = 2

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/fallout/sentrybot.mdl"
ITEM.maleModel = "models/fallout/sentrybot.mdl"

ITEM.skin = 3
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"

ITEM.specialBonus = {}

ITEM.armorRace = {
    ["human"] = false,
    ["sentrybot"] = true
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = false,
    body = true,
}

ITEM.takesBody = {
    hair = false,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
