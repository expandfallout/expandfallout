ITEM.name = "NCR Lead Heavy Trooper Armor"
ITEM.description = "Salvaged Power Armor used by the leader of NCR Heavy Troopers."
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/galang/fallout/player/eventncrt45.mdl"
ITEM.maleModel = "models/galang/fallout/player/eventncrt45.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {}

ITEM.resistance = 83
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "Lead - Shock"

ITEM.specialBonus = {
	agility = 2
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
