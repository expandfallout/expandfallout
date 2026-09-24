ITEM.name = "Gun Runner Guard Armor"
ITEM.description = "Armor worn by Gun Runners."
ITEM.model = "models/fallout/apparel/enclave_power_armor.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/armor/combat-classic.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/combat-classic.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "GR"

ITEM.specialBonus = {
	perception = 1
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
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
