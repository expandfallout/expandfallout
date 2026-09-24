ITEM.name = "Surgical Mask"
ITEM.description = "A surgical mask, often worn by doctor's such as the FoA to prevent disease."
ITEM.model = "models/fallout/apparel/tophat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "mask"

ITEM.femaleModel = "models/catmop/fallout/player/male/masks/surgicalmask.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/masks/surgicalmask.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 15
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "FoA"

ITEM.specialBonus = {
	intelligence = 3
}

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
