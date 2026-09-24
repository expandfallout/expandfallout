ITEM.name = "Legion Centurion helmet"
ITEM.description = "A heavy helmet worn by Centurions."
ITEM.model = "models/fallout/apparel/centurionhelmet_go.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/centurionhelmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/centurionhelmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 70
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Legion"
ITEM.factionClass = "Officer"

ITEM.specialBonus = {
	strength = 4
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
