ITEM.name = "Advanced Hazard Mask"
ITEM.description = "This looks priceless."
ITEM.model = "models/fallout/apparel/cowboyhat4.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/catmop/fallout/player/male/masks/ulyssmask.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/masks/ulyssmask.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 100
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "C.I.T"

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = false,
    mask = true,
    eyes = false,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = false,
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
