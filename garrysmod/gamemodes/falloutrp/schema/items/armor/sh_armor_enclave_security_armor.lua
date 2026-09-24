ITEM.name = "Enclave Security Armor"
ITEM.description = "A set of combat armor issued by the Enclave. | ENLISTED ARMOR"
ITEM.model = "models/fallout/apparel/mark1combat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/armor/enclave_security.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/enclave_security.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Enclave"

ITEM.specialBonus = {
	intelligence = 2
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
