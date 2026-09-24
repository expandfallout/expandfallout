ITEM.name = "Legion Instructor Armor"
ITEM.description = "A set of armor worn by instructors in Caesar's Legion."
ITEM.model = "models/fallout/apparel/legiongo.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/ryse/instructor.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/ryse/instructor.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 68
ITEM.speedBoost = 25
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 50

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Legion"
ITEM.factionClass = "Officer"

ITEM.specialBonus = {}

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
