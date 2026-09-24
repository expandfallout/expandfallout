ITEM.name = "NCR Medics Backpack"
ITEM.description = "A backpack used by NCR medics to carry supplies."
ITEM.model = "models/catmop/fallout/props/ncr_backpack_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "backpack"

ITEM.femaleModel = "models/catmop/fallout/player/female/clothing/ncr_backpack.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/clothing/ncr_backpack.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 0
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"

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
