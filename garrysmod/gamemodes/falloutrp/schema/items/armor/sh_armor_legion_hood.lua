ITEM.name = "Legion Explorer Hood"
ITEM.description = "A hood worn by explorers in Caesar's Legion."
ITEM.model = "models/fallout/apparel/legionhood_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/legionhood.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/legionhood.mdl"

ITEM.skin = false
ITEM.bodyGroups = {
    [0] = 1
}

ITEM.resistance = 63
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Legion"
ITEM.factionClass = "Enlisted"

ITEM.specialBonus = {
	agility = 2
}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = false,
    body = false,
}

ITEM.takesBody = {
    hair = true,
    beard = false,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
