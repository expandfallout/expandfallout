ITEM.name = "NCR Scorched Sierra Helmet"
ITEM.description = "Salvaged Power Armor Helmet used by High Ranking NCR Officers."
ITEM.model = "models/fallout/apparel/power_armor_helmet.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/sierra_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/sierra_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 87
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "Lead - Faction"

ITEM.specialBonus = {
	perception = 5
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
