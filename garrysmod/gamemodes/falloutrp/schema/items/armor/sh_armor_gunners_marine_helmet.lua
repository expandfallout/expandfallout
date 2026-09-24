ITEM.name = "Gunners Marine Heavy Armor"
ITEM.description = "A set of marine heavy armor worn by the Gunners. | OFFICER"
ITEM.model = "models/fallout/apparel/combatarmorhelmet.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/widowz/fallout/player/faction/gunners/gunnersheavyhelmet.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/gunners/gunnersheavyhelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 68
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Gunners"
ITEM.factionClass = "OFFICER"

ITEM.specialBonus = {}

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
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
