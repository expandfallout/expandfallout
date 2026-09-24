ITEM.name = "Legion Heavy Centurion Armor"
ITEM.description = "A set of heavy armor worn by Centurions, donning a salvaged T-51 arm."
ITEM.model = "models/fallout/apparel/centuriongo.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/cnr/centurian2.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/cnr/centurian2.mdl"

ITEM.skin = false
ITEM.bodyGroups = {
    [0] = 1
}

ITEM.resistance = 75
ITEM.speedBoost = -18
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 100

ITEM.isPA = false
ITEM.noCore = false
ITEM.isSalvagedPA = true

ITEM.faction = "Legion"
ITEM.factionClass = "High Command"

ITEM.specialBonus = {
	endurance = 4
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
