ITEM.name = "Proto-Combat Helmet"
ITEM.description = "A next generation prototype combat helmet, developed in use for covert operations by the U.S. Military pre-war. The helmet eyes glow a bright green to help in dark environments."
ITEM.model = "models/fallout/apparel/combatarmorhelmet.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/boulder/protocombathelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/boulder/protocombathelmet.mdl"

ITEM.skin = 2
ITEM.bodyGroups = {}

ITEM.resistance = 66
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 15
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Boulder Dome"

ITEM.specialBonus = {
	intelligence = 2
}

ITEM.takesType = {
    hat = false,
    mask = false,
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
