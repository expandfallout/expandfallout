ITEM.name = "Legion Recruit Decanus Helmet"
ITEM.description = "A helmet worn by Legion Decanus recruits."
ITEM.model = "models/fallout/apparel/legionfeatherhead01_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/legionfeatherhead01.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/legionfeatherhead01.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 66
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Legion"

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
