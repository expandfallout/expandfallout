ITEM.name = "Ghost Gas Mask"
ITEM.description = "A gas mask used to protect the wearer from hazardous airborne substances."
ITEM.model = "models/catmop/fallout/props/ncr_gasmask_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "mask"

ITEM.femaleModel = "models/catmop/fallout/player/male/headware/ncr_gaskmask.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/headware/ncr_gaskmask.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 50
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	agility = 1
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = true,
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
