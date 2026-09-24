ITEM.name = "Legion Legate Helmet"
ITEM.description = "A personal helmet worn by Legate in Caesar's Legion."
ITEM.model = "models/fallout/apparel/legatehelmgo.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/legatehelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/legatehelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 87
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Legion"
ITEM.factionClass = "Legate"

ITEM.specialBonus = {
	strength = 5
}

ITEM.armorRace = {
    ["human"] = true,
    ["legion_legatus"] = true,
}

ITEM.takesType = {
    hat = true,
    mask = true,
    eyes = true,
    helmet = true,
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
