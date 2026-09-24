ITEM.name = "Legion Veteran Helmet"
ITEM.description = "A helmet worn by Legion veterans."
ITEM.model = "models/fallout/apparel/legionwhitehelmetbase_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/legionwhitehelmetbase.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/legionwhitehelmetbase.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 64
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Legion"
ITEM.factionClass = "Enlisted"

ITEM.specialBonus = {
	strength = 2
}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
