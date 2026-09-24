ITEM.name = "Clown Mask"
ITEM.description = "A colorful mask that adds a touch of whimsy to any outfit."
ITEM.model = "models/props_junk/TrafficCone001a.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/clown_mask.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/clown_mask.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 55
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	strength = 3
}

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
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
