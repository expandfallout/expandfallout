ITEM.name = "Raider Cage Armor"
ITEM.description = "A caged armor set used by the Pitt Raiders. | Pitt Raiders Enlisted Armor"
ITEM.model = "models/fallout/apparel/raiderarmor01.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/cagearmor.mdl"
ITEM.maleModel = "models/galang/fallout/player/cagearmor.mdl"

ITEM.skin = 1
ITEM.bodyGroups = {}

ITEM.resistance = 72
ITEM.speedBoost = -10
ITEM.jumpBoost = 0
ITEM.radResistance = 0
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "Pitt Raider"

ITEM.specialBonus = {
	strength = 2
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
