ITEM.name = "NCR Lead Heavy Trooper Helmet"
ITEM.description = "Salvaged Power Armor Helmet used by the leader of NCR Heavy Troopers."
ITEM.model = "models/fallout/apparel/power_armor_helmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/galang/fallout/player/eventncrt45helmet.mdl"
ITEM.maleModel = "models/galang/fallout/player/eventncrt45helmet.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 83
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "Lead - Shock"

ITEM.specialBonus = {
	perception = 4
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
    head = true
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
