ITEM.name = "BoS Recon Helmet"
ITEM.description = "A helmet used by the Brotherhood of Steel's reconnaissance units."
ITEM.model = "models/fallout/apparel/raiderarmorhelmet.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "helmet"

ITEM.femaleModel = "models/roadkill/fallout/player/male/headgear/bos_recon_helmet.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/headgear/bos_recon_helmet.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 55
ITEM.speedBoost = 0
ITEM.jumpBoost = 0
ITEM.radResistance = 25
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "BoS"
ITEM.factionClass = "Enlisted"

ITEM.specialBonus = {
	intelligence = 2
}

ITEM.takesType = {
    hat = false,
    mask = false,
    eyes = false,
    helmet = true,
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
