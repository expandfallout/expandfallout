ITEM.name = "Motorcycle Helmet"
ITEM.description = "A heavy armor made from reinforced metal, reinforced for extra protection."
ITEM.model = "models/props_junk/TrafficCone001a.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/motorcycle_hat.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/motorcycle_hat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 61
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	perception = -1
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
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
