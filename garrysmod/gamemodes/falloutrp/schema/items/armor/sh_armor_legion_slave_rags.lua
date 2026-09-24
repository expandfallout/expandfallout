ITEM.name = "Legion Slave Rags"
ITEM.description = "A set of rags worn by those who are slaves in Caesar's Legion."
ITEM.model = "models/fallout/apparel/slaverags_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/clothing/slave_rags.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/clothing/slave_rags.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 10
ITEM.speedBoost = 10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Wasteland/Legion"

ITEM.specialBonus = {
	strength = 8
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
