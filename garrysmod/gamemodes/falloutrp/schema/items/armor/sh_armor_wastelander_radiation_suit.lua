ITEM.name = "Radiation Suit"
ITEM.description = "An enclosed suit designed to protect the wearer from radiation."
ITEM.model = "models/thespireroleplay/items/clothes/group009.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/armor/radiationsuit.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/radiationsuit.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 50
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	intelligence = 3
}

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
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
