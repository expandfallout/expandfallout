ITEM.name = "Raider Battle Helmet"
ITEM.description =  "A bone helmet used by the Raiders."
ITEM.model = "models/fallout/apparel/helmetraider03.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/fiend_battle_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/fiend_battle_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 63
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Raider"

ITEM.specialBonus = {
	perception = 2
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
