ITEM.name = "Gunners T-60 Power Armor"
ITEM.description = "A set of T-60 power armor worn by the Gunners. | OFFICER"
ITEM.model = "models/fallout/apparel/t60pago.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/widowz/fallout/player/faction/gunners/gunnert60armor.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/gunners/gunnert60armor.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "Gunners"
ITEM.factionClass = "OFFICER"

ITEM.specialBonus = {
	perception = 4
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
