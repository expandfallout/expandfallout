ITEM.name = "Vault-Tec Cleanroom Hood"
ITEM.description = "An advanced cleanroom suit."
ITEM.model = "models/fallout/apparel/wastelandmerchant01.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/institutecleanroomhood.mdl"
ITEM.maleModel = "models/galang/fallout/player/institutecleanroomhood.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.faction = "VT"

ITEM.resistance = 55
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 25
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

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
    head = false
}

ITEM.armorRace = {
    ["human"] = true,
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
