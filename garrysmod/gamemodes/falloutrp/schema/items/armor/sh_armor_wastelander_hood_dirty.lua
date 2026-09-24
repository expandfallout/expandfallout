ITEM.name = "Hood, Dirty"
ITEM.description = "A dirty white cloth hood."
ITEM.model = "models/galang/fallout/player/accessories/capego.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/galang/fallout/player/accessories/hood.mdl"
ITEM.maleModel = "models/galang/fallout/player/accessories/hood.mdl"

ITEM.skin = 2
ITEM.bodyGroups = {}

ITEM.resistance = 2
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
