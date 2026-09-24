ITEM.name = "FoA Plague Doctor Mask"
ITEM.description = "A plague doctor mask, often worn by doctor's such as the FoA to prevent disease. | Faction Lead"
ITEM.model = "models/fallout/apparel/tophat.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/catmop/fallout/player/male/headware/plaguedoctormask.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/headware/plaguedoctormask.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 25
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
