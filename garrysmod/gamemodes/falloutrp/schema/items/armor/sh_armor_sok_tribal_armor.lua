ITEM.name = "Tribal Armor"
ITEM.description = "A Tribal Armor Used By The Sons Of Kaga."
ITEM.model = "models/catmop/fallout/props/tribal_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/female/clothing/tribal.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/clothing/tribal.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 60
ITEM.speedBoost = 10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "SOK"

ITEM.specialBonus = {
	intelligence = 1
}

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
