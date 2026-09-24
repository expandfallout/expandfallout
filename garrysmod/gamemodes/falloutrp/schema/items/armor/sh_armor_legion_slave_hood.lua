ITEM.name = "Legion Slave Hood"
ITEM.description = "A ragged hood worn by slaves in Caesar's Legion."
ITEM.model = "models/fallout/apparel/slaverags_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/slave_scarf.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/slave_scarf.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 10
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Wasteland/Legion"

ITEM.specialBonus = {
	strength = 2
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
