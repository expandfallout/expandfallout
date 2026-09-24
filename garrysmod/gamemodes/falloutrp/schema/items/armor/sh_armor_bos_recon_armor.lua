ITEM.name = "BoS Recon Armor"
ITEM.description = "A lightweight armor used by the Brotherhood of Steel's reconnaissance units."
ITEM.model = "models/fallout/apparel/bosunderarmor.mdl"

ITEM.width = 1
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = false

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/female/armor/bos_recon.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/bos_recon.mdl"

ITEM.skin = false
ITEM.bodyGroups = {}

ITEM.resistance = 55
ITEM.speedBoost = 15
ITEM.jumpBoost = 10
ITEM.radResistance = 35
ITEM.fallProtection = 0

ITEM.isPA = false
ITEM.noCore = false

ITEM.faction = "BoS"
ITEM.factionClass = "Enlisted"

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
