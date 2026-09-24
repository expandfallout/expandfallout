ITEM.name = "Cape, White"
ITEM.description = "A white cloth cape."
ITEM.model = "models/galang/fallout/player/accessories/capego.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "bodyAccessory"

ITEM.femaleModel = "models/galang/fallout/player/accessories/cape.mdl"
ITEM.maleModel = "models/galang/fallout/player/accessories/cape.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
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
