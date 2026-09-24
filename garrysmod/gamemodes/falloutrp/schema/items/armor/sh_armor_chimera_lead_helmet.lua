ITEM.name = "Chimera Lead Helmet"
ITEM.description = "A helmet worn by the leader of Chimera."
ITEM.model = "models/props_junk/TrafficCone001a.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/catmop/fallout/player/male/headware/razorleadhelmet.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/headware/razorleadhelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 100
ITEM.fallProtection = 0

ITEM.faction = "CHIMERA"

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = true,
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
