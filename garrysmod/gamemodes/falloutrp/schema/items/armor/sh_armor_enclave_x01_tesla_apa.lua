ITEM.name = "X-01 Tesla Advanced Powered Armor"
ITEM.description = "A suit of APA, embodied in Tesla Coils to improve energy resistance. | FL ARMOR"
ITEM.model = "models/fallout/apparel/tesleakpowerarmor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/remnants_tesla.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/remnants_tesla.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 87
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "Enclave"

ITEM.specialBonus = {
	intelligence = 5
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
