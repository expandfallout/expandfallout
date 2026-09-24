ITEM.name = "Stormchaser Hat"
ITEM.description = "A hat commonly worn by traders in the wasteland."
ITEM.model = "models/props_junk/TrafficCone001a.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/stormchaser_hat.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/stormchaser_hat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 40
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	endurance = 1
}

ITEM.takesType = {
    hat = true,
    mask = false,
    eyes = false,
    helmet = true,
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
