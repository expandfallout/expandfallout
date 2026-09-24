ITEM.name = "FoA Responders Mask"
ITEM.description = "A refitted pre-war firefighters mask, used by Responders of the FoA."
ITEM.model = "models/catmop/fallout/props/gas_mask_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "mask"

ITEM.femaleModel = "models/widowz/fallout/player/Faction/FOAFireHead.mdl"
ITEM.maleModel = "models/widowz/fallout/player/Faction/FOAFireHead.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 67
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "FOA"

ITEM.specialBonus = {}

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
