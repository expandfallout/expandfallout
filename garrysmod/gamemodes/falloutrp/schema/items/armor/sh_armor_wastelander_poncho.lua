ITEM.name = "Poncho, Carpet"
ITEM.description = "A makeshift poncho made from scavenged materials."
ITEM.model = "models/catmop/fallout/props/tuxedogo.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "bodyAccessory"

ITEM.femaleModel = "models/galang/fallout/player/ponchof.mdl"
ITEM.maleModel = "models/galang/fallout/player/poncho.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 5
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {}

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
