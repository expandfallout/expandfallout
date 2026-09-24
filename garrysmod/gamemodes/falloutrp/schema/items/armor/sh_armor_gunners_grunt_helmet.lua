ITEM.name = "Gunners Grunt Helmet"
ITEM.description = "A set of armor worn by the Gunner Grunts. | ENLISTED"
ITEM.model = "models/fallout/apparel/combatarmorhelmet.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/widowz/fallout/player/faction/gunners/gunnercombathelmet.mdl"
ITEM.maleModel = "models/widowz/fallout/player/faction/gunners/gunnercombathelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Gunners"
ITEM.factionClass = "ENLISTED"

ITEM.specialBonus = {}

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
