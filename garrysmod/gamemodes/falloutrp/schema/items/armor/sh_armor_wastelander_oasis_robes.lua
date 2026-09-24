ITEM.name = "Oasis Robes"
ITEM.description = "Robes worn by inhabitants of Oasis, worshipping the Tree of Life."
ITEM.model = "models/catmop/fallout/props/oasis_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/female/clothing/oasis.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/clothing/oasis.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 55
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
