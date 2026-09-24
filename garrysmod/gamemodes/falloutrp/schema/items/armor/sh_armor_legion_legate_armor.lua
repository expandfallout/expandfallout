ITEM.name = "Legion Legate Armor"
ITEM.description = "A personal armor worn by Legate in Caesar's Legion."
ITEM.model = "models/fallout/apparel/legatearmor_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/legate.mdl"
ITEM.maleModel = "models/galang/fallout/player/legate.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 87
ITEM.speedBoost = 15
ITEM.jumpBoost = 60
ITEM.radResistance = 70
ITEM.fallProtection = 50

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Legion"
ITEM.factionClass = "Legate"

ITEM.specialBonus = {
	endurance = 5
}

ITEM.armorRace = {
    ["human"] = true,
    ["legion_legatus"] = true,
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
