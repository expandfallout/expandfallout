ITEM.name = "Wheathered X-01 Advanced Powered Armor"
ITEM.description = "The most advanced suit of PA developed by the Enclave. | HIGH COMMAND ARMOR"
ITEM.model = "models/fallout/apparel/adpowerarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/male/armor/remnant_armor.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/remnant_armor.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 83
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "Enclave"

ITEM.specialBonus = {
	intelligence = 4
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
