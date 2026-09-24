ITEM.name = "NCR Scorched Sierra Armor"
ITEM.description = "Salvaged Power Armor used by High Ranking NCR Officers."
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/sierra.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/sierra.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 87
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "NCR"
ITEM.factionClass = "Lead - Faction"

ITEM.specialBonus = {
	agility = 3
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
