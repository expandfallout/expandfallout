ITEM.name = "NCR Patrol Ranger Hat"
ITEM.description = "A hat worn by NCR patrol rangers."
ITEM.model = "models/fallout/apparel/cowboyhat2.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "hat"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/rangerhat.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/rangerhat.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 68
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "SNCO - Rangers"

ITEM.specialBonus = {
	perception = 3
}

ITEM.takesType = {
    hat = false,
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
