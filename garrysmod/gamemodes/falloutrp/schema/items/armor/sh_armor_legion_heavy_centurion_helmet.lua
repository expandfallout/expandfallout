ITEM.name = "Legion Heavy Centurion Helmet"
ITEM.description = "A set of heavy armor worn by Centurions, donning a salvaged T-51 arm."
ITEM.model = "models/fallout/apparel/centurionhelmet_go.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/cnr/centurian_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/cnr/centurian_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = false

ITEM.resistance = 75
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 20
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false
ITEM.isSalvagedPA = true

ITEM.faction = "Legion"
ITEM.factionClass = "High Command"

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
    beard = true,
    head = false
}

ITEM.OnEquip = function(item, client)
    return true
end

ITEM.OnUnequip = function(item, client)
    return true
end
