ITEM.name = "NCR Heavy Trooper Armor"
ITEM.description = "Salvaged Power Armor used by NCR Heavy Troopers."
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/ncrsalvaged.mdl"
ITEM.maleModel = "models/galang/fallout/player/ncrsalvaged.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 75
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 60
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false
ITEM.isSalvagedPA = true

ITEM.faction = "NCR"
ITEM.factionClass = "NCO - Shock"

ITEM.specialBonus = {
	agility = 1
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
