ITEM.name = "BoS T-45 Armor"
ITEM.description = "A set of T-45 power armor used by the Knights of the Brotherhood of Steel."
ITEM.model = "models/fallout/apparel/power_armor.mdl"

ITEM.width = 2
ITEM.height = 1

ITEM.category = "Armor"
ITEM.playerHeight = 1.1

ITEM.bodyType = "body"

ITEM.femaleModel = "models/roadkill/fallout/player/male/armor/t-45.mdl"
ITEM.maleModel = "models/roadkill/fallout/player/male/armor/t-45.mdl"

ITEM.skin = 0
ITEM.bodyGroups = {
    [1] = 1
}

ITEM.resistance = 75
ITEM.speedBoost = -63
ITEM.jumpBoost = 0
ITEM.radResistance = 70
ITEM.fallProtection = 0

ITEM.isPA = true
ITEM.noCore = false

ITEM.faction = "BoS"
ITEM.factionClass = "NCO - Knights"

ITEM.specialBonus = {
	strength = 3
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
