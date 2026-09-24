ITEM.name = "West Tek Corporate Beret"
ITEM.description = "A cap worn by pre-war military personnel as-well as it's contractors."
ITEM.model = "models/fallout/apparel/red_beret.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/widowz/fallout/player/widowzcc/militaryintelhat.mdl"
ITEM.maleModel = "models/widowz/fallout/player/widowzcc/militaryintelhat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "West-Tek"
ITEM.factionClass = "Officer - West Tek"

ITEM.specialBonus = {
	charisma = 2,
	intelligence = 2
}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
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
