ITEM.name = "Raider Cage Helmet"
ITEM.description =  "A caged helmet used by the Pitt Raiders. | Pitt Raiders Enlisted Armor"
ITEM.model = "models/fallout/headgear/helmetraider03.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/cagearmorhelmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/cagearmorhelmet.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 72
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 50
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Pitt Raiders"

ITEM.specialBonus = {}

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
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
