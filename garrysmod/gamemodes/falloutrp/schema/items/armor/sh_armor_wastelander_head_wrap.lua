ITEM.name = "Head Wrap"
ITEM.description = "A simple cloth wrap for the head."
ITEM.model = "models/fallout/apparel/headwrap.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/head_wrap.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/head_wrap.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 35
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.specialBonus = {}

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
