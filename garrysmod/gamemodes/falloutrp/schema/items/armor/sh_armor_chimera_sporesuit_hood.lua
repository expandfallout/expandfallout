ITEM.name = "Chimera Enhanced Spore Hood"
ITEM.description = "A hood enhanced with the Chimera FTO division's modified spore strain, intended to increase the physical mobility of the subject."
ITEM.model = "models/catmop/fallout/props/oasishood_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/widowz/fallout/player/faction/chimeraco22head.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/chimeraco22head.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 67
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.faction = "CHIMERA"

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	intelligence = 1
}

ITEM.takesType = {
    hat = false,
    mask = true,
    eyes = false,
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
