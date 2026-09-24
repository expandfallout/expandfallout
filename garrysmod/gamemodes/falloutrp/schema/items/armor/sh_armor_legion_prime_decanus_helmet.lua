ITEM.name = "Legion Prime Decanus Helmet"
ITEM.description = "A helmet worn by Prime Decanus Legionaries."
ITEM.model = "models/fallout/apparel/legionfeatherhead03_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/legionfeatherhead02.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/legionfeatherhead02.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 67
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Legion"
ITEM.factionClass = "NCO"

ITEM.specialBonus = {
	strength = 3
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
