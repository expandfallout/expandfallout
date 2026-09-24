ITEM.name = "Chimera Officer Armor"
ITEM.description = "A set of armor worn by officers of Chimera."
ITEM.model = "models/hunter/blocks/cube025x025x025.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/catmop/fallout/player/male/armor/razorbackarmor.mdl"
ITEM.maleModel = "models/catmop/fallout/player/male/armor/razorbackarmor.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {
    [1] = 1,
}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 100

ITEM.faction = "CHIMERA"

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {
	intelligence = 3
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
